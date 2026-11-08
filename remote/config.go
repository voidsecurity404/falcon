package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

// Config is the "remote" section of defaults.json merged with settings.json.
type Config struct {
	Enabled       bool  `json:"enabled"`
	Owner         int64 `json:"-"`
	OwnerText     any   `json:"owner"`
	TerminalRoot  bool  `json:"terminalRoot"`
	Power         bool  `json:"power"`
	NotifyBoot    bool  `json:"notifyBoot"`
	ChatClipboard bool  `json:"chatClipboard"`
	Screen        bool  `json:"screen"`
}

func home() string {
	h, _ := os.UserHomeDir()
	return h
}

func configDir() string {
	if d := os.Getenv("XDG_CONFIG_HOME"); d != "" {
		return filepath.Join(d, "falcon")
	}
	return filepath.Join(home(), ".config/falcon")
}

func runtimeDir() string {
	base := os.Getenv("XDG_RUNTIME_DIR")
	if base == "" {
		base = fmt.Sprintf("/run/user/%d", os.Getuid())
	}
	return filepath.Join(base, "falcon-remote")
}

func statusPath() string { return filepath.Join(runtimeDir(), "status.json") }
func tokenPath() string  { return filepath.Join(configDir(), "remote-token") }

func readSection(path string) map[string]any {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	var all map[string]any
	if json.Unmarshal(data, &all) != nil {
		return nil
	}
	m, _ := all["remote"].(map[string]any)
	return m
}

func loadConfig() Config {
	merged := map[string]any{}
	for _, name := range []string{"defaults.json", "settings.json"} {
		for k, v := range readSection(filepath.Join(configDir(), name)) {
			merged[k] = v
		}
	}
	data, _ := json.Marshal(merged)
	var c Config
	json.Unmarshal(data, &c)
	switch v := c.OwnerText.(type) {
	case string:
		c.Owner, _ = strconv.ParseInt(strings.TrimSpace(v), 10, 64)
	case float64:
		c.Owner = int64(v)
	}
	return c
}

var tokenShape = regexp.MustCompile(`^\d{5,12}:[A-Za-z0-9_-]{30,}$`)

func validToken(t string) bool { return tokenShape.MatchString(t) }

func readToken() string {
	data, err := os.ReadFile(tokenPath())
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(data))
}

func writeToken(token string) error {
	os.MkdirAll(configDir(), 0o755)
	if token == "" {
		err := os.Remove(tokenPath())
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	tmp := tokenPath() + ".tmp"
	if err := os.WriteFile(tmp, []byte(token+"\n"), 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, tokenPath())
}

// stamp changes whenever one of the files the service reads changes.
func stamp() string {
	var b strings.Builder
	for _, p := range []string{filepath.Join(configDir(), "defaults.json"), filepath.Join(configDir(), "settings.json"), tokenPath()} {
		if st, err := os.Stat(p); err == nil {
			fmt.Fprintf(&b, "%d/%d;", st.ModTime().UnixNano(), st.Size())
		} else {
			b.WriteString("-;")
		}
	}
	return b.String()
}

// sessionEnv finds the graphical session even when the service started before login.
func sessionEnv() []string {
	env := os.Environ()
	base := filepath.Dir(runtimeDir())
	set := func(key, value string) {
		for i, kv := range env {
			if strings.HasPrefix(kv, key+"=") {
				env[i] = key + "=" + value
				return
			}
		}
		env = append(env, key+"="+value)
	}
	exists := func(p string) bool { _, err := os.Stat(p); return err == nil }
	newest := func(pattern string) string {
		files, _ := filepath.Glob(pattern)
		sort.Slice(files, func(i, j int) bool {
			a, _ := os.Stat(files[i])
			b, _ := os.Stat(files[j])
			return a != nil && b != nil && a.ModTime().After(b.ModTime())
		})
		for _, f := range files {
			if !strings.HasSuffix(f, ".lock") {
				return f
			}
		}
		return ""
	}
	if w := os.Getenv("WAYLAND_DISPLAY"); w == "" || !exists(filepath.Join(base, w)) {
		if f := newest(filepath.Join(base, "wayland-*")); f != "" {
			set("WAYLAND_DISPLAY", filepath.Base(f))
		}
	}
	if n := os.Getenv("NIRI_SOCKET"); n == "" || !exists(n) {
		if f := newest(filepath.Join(base, "niri.wayland-*.sock")); f != "" {
			set("NIRI_SOCKET", f)
		}
	}
	return env
}

func hasSession() bool {
	for _, kv := range sessionEnv() {
		if strings.HasPrefix(kv, "NIRI_SOCKET=") {
			_, err := os.Stat(strings.TrimPrefix(kv, "NIRI_SOCKET="))
			return err == nil
		}
	}
	return false
}
