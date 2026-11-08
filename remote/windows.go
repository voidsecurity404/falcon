package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"image"
	"image/jpeg"
	_ "image/png"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"
)

type Window struct {
	ID        int64   `json:"id"`
	Title     string  `json:"title"`
	AppID     string  `json:"appId"`
	Name      string  `json:"name"`
	PID       int     `json:"pid"`
	Workspace int     `json:"workspace"`
	Output    string  `json:"output"`
	Focused   bool    `json:"focused"`
	Floating  bool    `json:"floating"`
	Urgent    bool    `json:"urgent"`
	Age       float64 `json:"age"`
	CPU       float64 `json:"cpu"`
	Mem       uint64  `json:"mem"`
	Procs     int     `json:"procs"`
	Width     int     `json:"width"`
	Height    int     `json:"height"`
	Icon      bool    `json:"icon"`
}

func niri(args ...string) ([]byte, error) {
	cmd := exec.Command("niri", append([]string{"msg"}, args...)...)
	cmd.Env = sessionEnv()
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if err != nil {
		msg := strings.TrimSpace(stderr.String())
		if msg == "" {
			msg = err.Error()
		}
		return nil, errors.New(msg)
	}
	return out, nil
}

func listWindows(procs []Proc) ([]Window, error) {
	if !hasSession() {
		return nil, errors.New(tr("Nobody is logged in: the computer is at the login screen"))
	}
	raw, err := niri("-j", "windows")
	if err != nil {
		return nil, err
	}
	var ws []struct {
		ID          int64  `json:"id"`
		Title       string `json:"title"`
		AppID       string `json:"app_id"`
		PID         int    `json:"pid"`
		WorkspaceID int64  `json:"workspace_id"`
		Focused     bool   `json:"is_focused"`
		Floating    bool   `json:"is_floating"`
		Urgent      bool   `json:"is_urgent"`
		Layout      struct {
			Size []int `json:"window_size"`
		} `json:"layout"`
		Focus struct {
			Secs int64 `json:"secs"`
		} `json:"focus_timestamp"`
	}
	if err := json.Unmarshal(raw, &ws); err != nil {
		return nil, err
	}
	rawSpaces, _ := niri("-j", "workspaces")
	var spaces []struct {
		ID     int64  `json:"id"`
		Idx    int    `json:"idx"`
		Output string `json:"output"`
	}
	json.Unmarshal(rawSpaces, &spaces)
	spaceOf := map[int64]int{}
	outputOf := map[int64]string{}
	for _, s := range spaces {
		spaceOf[s.ID], outputOf[s.ID] = s.Idx, s.Output
	}

	byPID := map[int]Proc{}
	children := map[int][]int{}
	for _, p := range procs {
		byPID[p.PID] = p
		children[p.PPID] = append(children[p.PPID], p.PID)
	}
	var out []Window
	for _, w := range ws {
		win := Window{ID: w.ID, Title: w.Title, AppID: w.AppID, PID: w.PID, Workspace: spaceOf[w.WorkspaceID], Output: outputOf[w.WorkspaceID], Focused: w.Focused, Floating: w.Floating, Urgent: w.Urgent}
		if len(w.Layout.Size) == 2 {
			win.Width, win.Height = w.Layout.Size[0], w.Layout.Size[1]
		}
		entry := desktopEntry(w.AppID)
		win.Name = entry.name
		if win.Name == "" {
			win.Name = w.AppID
		}
		win.Icon = entry.icon != ""
		if p, ok := byPID[w.PID]; ok {
			win.Age = p.Age
			// The app's whole process tree, so a browser counts its tabs too.
			stack := []int{w.PID}
			for len(stack) > 0 {
				id := stack[len(stack)-1]
				stack = stack[:len(stack)-1]
				if q, ok := byPID[id]; ok {
					win.CPU += q.CPU
					win.Mem += q.Mem
					win.Procs++
				}
				stack = append(stack, children[id]...)
			}
		}
		out = append(out, win)
	}
	sort.SliceStable(out, func(i, j int) bool {
		if out[i].Workspace != out[j].Workspace {
			return out[i].Workspace < out[j].Workspace
		}
		return out[i].ID < out[j].ID
	})
	return out, nil
}

// Desktop entries give each app its real name and icon.

type entry struct{ name, icon string }

var (
	entriesOnce sync.Once
	entries     map[string]entry
	iconCache   sync.Map
)

func appDirs() []string {
	dirs := []string{filepath.Join(home(), ".local/share/applications")}
	data := os.Getenv("XDG_DATA_DIRS")
	if data == "" {
		data = "/usr/local/share:/usr/share"
	}
	for _, d := range strings.Split(data, ":") {
		dirs = append(dirs, filepath.Join(d, "applications"))
	}
	return append(dirs, "/var/lib/flatpak/exports/share/applications", filepath.Join(home(), ".local/share/flatpak/exports/share/applications"))
}

func loadEntries() {
	entries = map[string]entry{}
	lang := language()
	for i := len(appDirs()) - 1; i >= 0; i-- {
		files, _ := filepath.Glob(filepath.Join(appDirs()[i], "*.desktop"))
		for _, file := range files {
			f, err := os.Open(file)
			if err != nil {
				continue
			}
			var e entry
			var localName, wmClass string
			inMain := false
			scan := bufio.NewScanner(f)
			for scan.Scan() {
				line := scan.Text()
				if strings.HasPrefix(line, "[") {
					inMain = line == "[Desktop Entry]"
					continue
				}
				if !inMain {
					continue
				}
				k, v, ok := strings.Cut(line, "=")
				if !ok {
					continue
				}
				switch k {
				case "Name":
					e.name = v
				case "Name[" + lang + "]":
					localName = v
				case "Icon":
					e.icon = v
				case "StartupWMClass":
					wmClass = v
				}
			}
			f.Close()
			if localName != "" {
				e.name = localName
			}
			base := strings.ToLower(strings.TrimSuffix(filepath.Base(file), ".desktop"))
			entries[base] = e
			if wmClass != "" {
				entries[strings.ToLower(wmClass)] = e
			}
			if dot := strings.LastIndexByte(base, '.'); dot >= 0 {
				if _, taken := entries[base[dot+1:]]; !taken {
					entries[base[dot+1:]] = e
				}
			}
		}
	}
}

func desktopEntry(appID string) entry {
	entriesOnce.Do(loadEntries)
	id := strings.ToLower(appID)
	if e, ok := entries[id]; ok {
		return e
	}
	if dot := strings.LastIndexByte(id, '.'); dot >= 0 {
		if e, ok := entries[id[dot+1:]]; ok {
			return e
		}
	}
	return entry{icon: appID}
}

// iconFile looks an icon up in the usual themes, largest first.
func iconFile(appID string) string {
	if v, ok := iconCache.Load(appID); ok {
		return v.(string)
	}
	name := desktopEntry(appID).icon
	found := ""
	if filepath.IsAbs(name) {
		found = name
	} else if name != "" {
		roots := []string{filepath.Join(home(), ".local/share/icons"), filepath.Join(home(), ".icons"), "/usr/share/icons", "/var/lib/flatpak/exports/share/icons"}
		sizes := []string{"scalable", "512x512", "256x256", "128x128", "96x96", "64x64", "48x48", "32x32"}
	search:
		for _, theme := range []string{"hicolor", "Papirus", "Papirus-Dark", "breeze", "Adwaita", "*"} {
			for _, root := range roots {
				for _, size := range sizes {
					for _, ext := range []string{".svg", ".png"} {
						matches, _ := filepath.Glob(filepath.Join(root, theme, size, "apps", name+ext))
						if len(matches) > 0 {
							found = matches[0]
							break search
						}
					}
				}
			}
		}
		if found == "" {
			for _, ext := range []string{".svg", ".png", ".xpm"} {
				if _, err := os.Stat("/usr/share/pixmaps/" + name + ext); err == nil {
					found = "/usr/share/pixmaps/" + name + ext
					break
				}
			}
		}
	}
	iconCache.Store(appID, found)
	return found
}

// Screenshots.

var shotMu sync.Mutex

func toJPEG(png []byte, quality int) ([]byte, error) {
	img, _, err := image.Decode(bytes.NewReader(png))
	if err != nil {
		return nil, err
	}
	var buf bytes.Buffer
	err = jpeg.Encode(&buf, img, &jpeg.Options{Quality: quality})
	return buf.Bytes(), err
}

// windowShot asks niri for one window, even one on another workspace. niri also puts the picture on
// the clipboard, so the clipboard is saved before and put back after, and the picture leaves the history.
func windowShot(id int64) ([]byte, error) {
	if !hasSession() {
		return nil, errors.New(tr("Nobody is logged in: the computer is at the login screen"))
	}
	shotMu.Lock()
	defer shotMu.Unlock()
	dir := runtimeDir()
	os.MkdirAll(dir, 0o700)
	path := filepath.Join(dir, fmt.Sprintf("window-%d.png", id))
	os.Remove(path)
	saved, savedType := clipboardSave()
	if _, err := niri("action", "screenshot-window", "--id", fmt.Sprint(id), "--path", path); err != nil {
		return nil, err
	}
	var data []byte
	for i := 0; i < 40; i++ {
		time.Sleep(50 * time.Millisecond)
		if st, err := os.Stat(path); err == nil && st.Size() > 0 {
			time.Sleep(30 * time.Millisecond)
			data, _ = os.ReadFile(path)
			break
		}
	}
	os.Remove(path)
	time.Sleep(150 * time.Millisecond)
	forgetNewestPicture()
	clipboardRestore(saved, savedType)
	if data == nil {
		return nil, errors.New(tr("The window did not give a picture"))
	}
	return toJPEG(data, 82)
}

// screenJPEG takes every screen at once with grim.
func screenJPEG() ([]byte, error) {
	if !hasSession() {
		return nil, errors.New(tr("Nobody is logged in: the computer is at the login screen"))
	}
	cmd := exec.Command("grim", "-t", "jpeg", "-q", "80", "-")
	cmd.Env = sessionEnv()
	out, err := cmd.Output()
	if err != nil || len(out) == 0 {
		return nil, errors.New(tr("The screen could not be captured"))
	}
	return out, nil
}
