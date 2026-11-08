// falcon-remote: a Telegram bot with a Mini App that controls this computer from a phone.
//
//	falcon-remote run      the service: web app, tunnel and bot (systemd runs this)
//	falcon-remote token    saves the bot token read from FALCON_TOKEN or stdin, restarts the service
//	falcon-remote status   prints the service state as JSON
package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"sync"
	"time"
)

type App struct {
	mu      sync.Mutex
	cfg     Config
	token   string
	url     string
	bot     *Bot
	state   string
	errText string
	port    int
	sys     *Sampler
	term    *TermHub
}

func main() {
	log.SetFlags(log.Ltime)
	cmd := "run"
	if len(os.Args) > 1 {
		cmd = os.Args[1]
	}
	switch cmd {
	case "run":
		run(hasFlag("--no-bot"), hasFlag("--no-tunnel"))
	case "token":
		saveToken()
	case "status":
		data, err := os.ReadFile(statusPath())
		var st struct {
			PID int `json:"pid"`
		}
		json.Unmarshal(data, &st)
		// A status left behind by a process that is gone means stopped.
		if _, alive := os.Stat(fmt.Sprintf("/proc/%d", st.PID)); err != nil || st.PID == 0 || alive != nil {
			fmt.Println(`{"state":"stopped"}`)
			return
		}
		os.Stdout.Write(data)
	default:
		fmt.Fprintln(os.Stderr, "usage: falcon-remote [run|token|status]")
		os.Exit(2)
	}
}

func hasFlag(name string) bool {
	for _, a := range os.Args[2:] {
		if a == name {
			return true
		}
	}
	return false
}

func saveToken() {
	token := strings.TrimSpace(os.Getenv("FALCON_TOKEN"))
	if token == "" && !hasFlag("--clear") {
		data, _ := io.ReadAll(io.LimitReader(bufio.NewReader(os.Stdin), 4096))
		token = strings.TrimSpace(string(data))
	}
	if hasFlag("--clear") {
		token = ""
	}
	if token == "" && !hasFlag("--clear") {
		fmt.Fprintln(os.Stderr, "no token given: pass it in FALCON_TOKEN or on stdin, or use --clear")
		os.Exit(1)
	}
	if token != "" && !validToken(token) {
		fmt.Fprintln(os.Stderr, "this does not look like a bot token (123456:ABC...)")
		os.Exit(1)
	}
	if err := writeToken(token); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	exec.Command("systemctl", "--user", "try-restart", "falcon-remote.service").Run()
}

func run(noBot, noTunnel bool) {
	app := &App{state: "starting"}
	app.cfg = loadConfig()
	app.token = readToken()
	app.sys = NewSampler()
	app.term = NewTermHub(app)
	go app.watch()

	if app.token == "" && !noBot {
		app.setState("no-token", "")
	}

	ln, err := net.Listen("tcp", "127.0.0.1:"+envOr("FALCON_REMOTE_PORT", "0"))
	if err != nil {
		log.Fatal(err)
	}
	app.port = ln.Addr().(*net.TCPAddr).Port
	log.Printf("web app on http://127.0.0.1:%d", app.port)
	go func() { log.Fatal(http.Serve(ln, app.routes())) }()

	// Without a token nobody could open the app, so no tunnel either.
	if !noTunnel && (app.token != "" || noBot) {
		go app.tunnel()
	}
	if !noBot && app.token != "" {
		app.bot = NewBot(app.token)
		go app.botLoop()
	} else if noBot {
		app.setState("ready", "")
	}
	select {}
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func (a *App) config() Config {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.cfg
}

func (a *App) publicURL() string {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.url
}

func (a *App) setState(state, errText string) {
	a.mu.Lock()
	a.state, a.errText = state, errText
	a.mu.Unlock()
	a.writeStatus()
}

func (a *App) writeStatus() {
	a.mu.Lock()
	st := map[string]any{"state": a.state, "error": a.errText, "url": a.url, "owner": a.cfg.Owner != 0, "pid": os.Getpid()}
	if a.bot != nil {
		st["bot"] = a.bot.Username()
	}
	a.mu.Unlock()
	data, _ := json.Marshal(st)
	path := statusPath()
	os.MkdirAll(runtimeDir(), 0o700)
	tmp := path + ".tmp"
	if os.WriteFile(tmp, data, 0o600) == nil {
		os.Rename(tmp, path)
	}
}

// watch reloads the settings when they change. A new token restarts the process through systemd.
func (a *App) watch() {
	last := stamp()
	for range time.Tick(2 * time.Second) {
		now := stamp()
		if now == last {
			continue
		}
		last = now
		if readToken() != a.token {
			log.Print("the token changed, restarting")
			os.Exit(3)
		}
		cfg := loadConfig()
		a.mu.Lock()
		ownerChanged := cfg.Owner != a.cfg.Owner
		a.cfg = cfg
		a.mu.Unlock()
		a.writeStatus()
		if ownerChanged && a.bot != nil {
			go a.announce(false)
		}
	}
}
