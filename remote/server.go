package main

import (
	"embed"
	"encoding/json"
	"errors"
	"io"
	"io/fs"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"syscall"

	"github.com/gorilla/websocket"
)

//go:embed web
var webFiles embed.FS

var upgrader = websocket.Upgrader{CheckOrigin: func(*http.Request) bool { return true }}

func (a *App) routes() http.Handler {
	mux := http.NewServeMux()
	static, _ := fs.Sub(webFiles, "web")
	files := http.FileServer(http.FS(static))
	mux.Handle("GET /", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-cache")
		files.ServeHTTP(w, r)
	}))
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) { w.Write([]byte("ok")) })

	api := func(pattern string, h func(w http.ResponseWriter, r *http.Request) (any, error)) {
		mux.HandleFunc(pattern, func(w http.ResponseWriter, r *http.Request) {
			if !a.authorized(w, r) {
				return
			}
			out, err := h(w, r)
			if out == nil && err == nil {
				return // the handler wrote the reply itself
			}
			writeJSON(w, out, err)
		})
	}
	api("GET /api/hello", a.hello)
	api("GET /api/overview", func(w http.ResponseWriter, r *http.Request) (any, error) {
		a.sys.Touch()
		o, _ := a.sys.Get()
		return o, nil
	})
	api("GET /api/procs", a.procs)
	api("POST /api/procs/{pid}/signal", a.signal)
	api("GET /api/windows", func(w http.ResponseWriter, r *http.Request) (any, error) {
		a.sys.Touch()
		_, procs := a.sys.Get()
		ws, err := listWindows(procs)
		if ws == nil {
			ws = []Window{}
		}
		return map[string]any{"windows": ws, "screen": a.config().Screen}, err
	})
	api("GET /api/windows/{id}/shot", func(w http.ResponseWriter, r *http.Request) (any, error) {
		if !a.config().Screen {
			return nil, errors.New(tr("Screenshots are turned off in the settings."))
		}
		id, _ := strconv.ParseInt(r.PathValue("id"), 10, 64)
		data, err := windowShot(id)
		if err != nil {
			return nil, err
		}
		writeImage(w, data, "image/jpeg")
		return nil, nil
	})
	api("POST /api/windows/{id}/{action}", func(w http.ResponseWriter, r *http.Request) (any, error) {
		id := r.PathValue("id")
		switch r.PathValue("action") {
		case "focus":
			_, err := niri("action", "focus-window", "--id", id)
			return map[string]bool{"ok": err == nil}, err
		case "close":
			_, err := niri("action", "close-window", "--id", id)
			return map[string]bool{"ok": err == nil}, err
		}
		return nil, errors.New("unknown action")
	})
	api("GET /api/icon/{app}", func(w http.ResponseWriter, r *http.Request) (any, error) {
		path := iconFile(r.PathValue("app"))
		data, err := os.ReadFile(path)
		if path == "" || err != nil {
			http.NotFound(w, r)
			return nil, nil
		}
		mime := "image/png"
		if strings.HasSuffix(path, ".svg") {
			mime = "image/svg+xml"
		}
		w.Header().Set("Cache-Control", "private, max-age=86400")
		writeImage(w, data, mime)
		return nil, nil
	})
	api("GET /api/screen", func(w http.ResponseWriter, r *http.Request) (any, error) {
		if !a.config().Screen {
			return nil, errors.New(tr("Screenshots are turned off in the settings."))
		}
		data, err := screenJPEG()
		if err != nil {
			return nil, err
		}
		writeImage(w, data, "image/jpeg")
		return nil, nil
	})
	api("GET /api/clipboard", func(w http.ResponseWriter, r *http.Request) (any, error) {
		text, err := clipboardText()
		_, imgType := clipboardImage()
		return map[string]any{"text": text, "image": imgType != ""}, err
	})
	api("GET /api/clipboard/image", func(w http.ResponseWriter, r *http.Request) (any, error) {
		data, mime := clipboardImage()
		if data == nil {
			http.NotFound(w, r)
			return nil, nil
		}
		writeImage(w, data, mime)
		return nil, nil
	})
	api("POST /api/clipboard", func(w http.ResponseWriter, r *http.Request) (any, error) {
		r.Body = http.MaxBytesReader(w, r.Body, 30<<20)
		if strings.HasPrefix(r.Header.Get("Content-Type"), "image/") {
			data, err := io.ReadAll(r.Body)
			if err != nil {
				return nil, err
			}
			return map[string]bool{"ok": true}, setClipboardImage(data)
		}
		var body struct {
			Text string `json:"text"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			return nil, err
		}
		return map[string]bool{"ok": true}, setClipboard([]byte(body.Text), "text/plain;charset=utf-8")
	})
	api("GET /api/controls", a.controls)
	api("POST /api/action/{name}", a.action)
	api("POST /api/term/kill", func(w http.ResponseWriter, r *http.Request) (any, error) {
		a.term.Kill()
		return map[string]bool{"ok": true}, nil
	})
	mux.HandleFunc("GET /api/term", func(w http.ResponseWriter, r *http.Request) {
		if !a.authorized(w, r) {
			return
		}
		c, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			return
		}
		cols, _ := strconv.Atoi(r.URL.Query().Get("cols"))
		rows, _ := strconv.Atoi(r.URL.Query().Get("rows"))
		a.term.Serve(c, cols, rows, r.URL.Query().Get("fresh") == "1")
	})
	return mux
}

func (a *App) authorized(w http.ResponseWriter, r *http.Request) bool {
	raw := r.Header.Get("X-Init-Data")
	if raw == "" {
		raw = r.URL.Query().Get("auth")
	}
	a.mu.Lock()
	token, owner := a.token, a.cfg.Owner
	a.mu.Unlock()
	if err := checkInitData(raw, token, owner); err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusForbidden)
		json.NewEncoder(w).Encode(map[string]string{"error": tr(err.Error())})
		return false
	}
	return true
}

func writeJSON(w http.ResponseWriter, out any, err error) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	if err != nil {
		w.WriteHeader(http.StatusBadGateway)
		json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
		return
	}
	json.NewEncoder(w).Encode(out)
}

func writeImage(w http.ResponseWriter, data []byte, mime string) {
	w.Header().Set("Content-Type", mime)
	if w.Header().Get("Cache-Control") == "" {
		w.Header().Set("Cache-Control", "no-store")
	}
	w.Write(data)
}

func (a *App) hello(w http.ResponseWriter, r *http.Request) (any, error) {
	cfg := a.config()
	theme := map[string]string{}
	if data, err := os.ReadFile(filepath.Join(stateDir(), "colors.json")); err == nil {
		json.Unmarshal(data, &theme)
	}
	host, _ := os.Hostname()
	user := os.Getenv("USER")
	if u, err := userName(uint32(os.Getuid()), &Sampler{users: map[uint32]string{}}); err == nil {
		user = u
	}
	return map[string]any{
		"host": host, "user": user, "theme": theme, "i18n": translations(), "lang": language(),
		"terminalRoot": cfg.TerminalRoot, "power": cfg.Power, "screen": cfg.Screen,
	}, nil
}

func (a *App) procs(w http.ResponseWriter, r *http.Request) (any, error) {
	a.sys.Touch()
	o, all := a.sys.Get()
	q := strings.ToLower(strings.TrimSpace(r.URL.Query().Get("q")))
	mineOnly := r.URL.Query().Get("mine") == "1"
	list := make([]Proc, 0, len(all))
	for _, p := range all {
		if mineOnly && !p.Mine {
			continue
		}
		if q != "" && !strings.Contains(strings.ToLower(p.Name), q) && !strings.Contains(strings.ToLower(p.Cmd), q) && strconv.Itoa(p.PID) != q && p.User != q {
			continue
		}
		list = append(list, p)
	}
	sortBy := r.URL.Query().Get("sort")
	sort.SliceStable(list, func(i, j int) bool {
		x, y := list[i], list[j]
		switch sortBy {
		case "mem":
			return x.Mem > y.Mem
		case "pid":
			return x.PID < y.PID
		case "name":
			return strings.ToLower(x.Name) < strings.ToLower(y.Name)
		case "age":
			return x.Age > y.Age
		}
		if x.CPU != y.CPU {
			return x.CPU > y.CPU
		}
		return x.Mem > y.Mem
	})
	total := len(list)
	if len(list) > 250 {
		list = list[:250]
	}
	return map[string]any{"procs": list, "total": total, "all": len(all), "memTotal": o.Mem.Total, "cores": len(o.Cores)}, nil
}

func (a *App) signal(w http.ResponseWriter, r *http.Request) (any, error) {
	pid, _ := strconv.Atoi(r.PathValue("pid"))
	var body struct {
		Signal string `json:"signal"`
	}
	json.NewDecoder(r.Body).Decode(&body)
	sig := map[string]syscall.Signal{"TERM": syscall.SIGTERM, "KILL": syscall.SIGKILL, "STOP": syscall.SIGSTOP, "CONT": syscall.SIGCONT, "HUP": syscall.SIGHUP}[body.Signal]
	if sig == 0 || pid <= 1 || pid == os.Getpid() {
		return nil, errors.New("not allowed")
	}
	if err := syscall.Kill(pid, sig); err != nil {
		if errors.Is(err, syscall.EPERM) {
			return nil, errors.New(tr("This process belongs to another user. Use the root terminal."))
		}
		return nil, err
	}
	return map[string]bool{"ok": true}, nil
}

func output(name string, args ...string) string {
	cmd := exec.Command(name, args...)
	cmd.Env = sessionEnv()
	out, _ := cmd.Output()
	return strings.TrimSpace(string(out))
}

func (a *App) controls(w http.ResponseWriter, r *http.Request) (any, error) {
	res := map[string]any{"volume": nil, "player": nil}
	// "Volume: 0.45 [MUTED]"
	if f := strings.Fields(output("wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@")); len(f) >= 2 {
		v, _ := strconv.ParseFloat(f[1], 64)
		res["volume"] = map[string]any{"level": v, "muted": len(f) > 2}
	}
	if status := output("playerctl", "status"); status != "" && !strings.Contains(status, "No players") {
		res["player"] = map[string]string{
			"status": status,
			"title":  output("playerctl", "metadata", "title"),
			"artist": output("playerctl", "metadata", "artist"),
		}
	}
	return res, nil
}

func (a *App) action(w http.ResponseWriter, r *http.Request) (any, error) {
	name := r.PathValue("name")
	power := map[string][]string{"suspend": {"systemctl", "suspend"}, "reboot": {"systemctl", "reboot"}, "poweroff": {"systemctl", "poweroff"}}
	simple := map[string][]string{
		"lock":       {"loginctl", "lock-sessions"},
		"volumeUp":   {"wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", "5%+"},
		"volumeDown": {"wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"},
		"mute":       {"wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"},
		"playPause":  {"playerctl", "play-pause"},
		"next":       {"playerctl", "next"},
		"previous":   {"playerctl", "previous"},
	}
	args, ok := simple[name]
	if p, isPower := power[name]; isPower {
		if !a.config().Power {
			return nil, errors.New(tr("Power actions are turned off in the settings."))
		}
		args, ok = p, true
	}
	if !ok {
		return nil, errors.New("unknown action")
	}
	cmd := exec.Command(args[0], args[1:]...)
	cmd.Env = sessionEnv()
	if out, err := cmd.CombinedOutput(); err != nil {
		msg := strings.TrimSpace(string(out))
		if msg == "" {
			msg = err.Error()
		}
		return nil, errors.New(msg)
	}
	return map[string]bool{"ok": true}, nil
}
