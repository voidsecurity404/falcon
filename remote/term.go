package main

import (
	"encoding/json"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/creack/pty"
	"github.com/gorilla/websocket"
)

const (
	scrollKeep = 256 << 10        // output kept for a reconnect
	idleKill   = 30 * time.Minute // a shell nobody looks at ends after this
)

// TermHub keeps one shell alive across reconnects: a Mini App reloads often on a phone,
// and the shell (with sudo's remembered password) should still be there.
type TermHub struct {
	app  *App
	mu   sync.Mutex
	sess map[bool]*termSession // by root
}

type termSession struct {
	cmd      *exec.Cmd
	pty      *os.File
	mu       sync.Mutex
	buf      []byte
	client   *websocket.Conn
	writeMu  sync.Mutex
	done     chan struct{}
	lastSeen time.Time
	root     bool
}

func NewTermHub(app *App) *TermHub {
	h := &TermHub{app: app, sess: map[bool]*termSession{}}
	go h.reaper()
	return h
}

func (h *TermHub) reaper() {
	for range time.Tick(time.Minute) {
		for _, root := range []bool{false, true} {
			h.mu.Lock()
			s := h.sess[root]
			h.mu.Unlock()
			if s == nil {
				continue
			}
			s.mu.Lock()
			idle := s.client == nil && time.Since(s.lastSeen) > idleKill
			s.mu.Unlock()
			// A root shell also ends when root is no longer allowed.
			if idle || (root && !h.app.config().TerminalRoot) {
				h.Kill(root)
			}
		}
	}
}

// Running says which shells are alive, so the app can show them.
func (h *TermHub) Running() map[string]bool {
	h.mu.Lock()
	defer h.mu.Unlock()
	return map[string]bool{"user": h.sess[false] != nil, "root": h.sess[true] != nil}
}

func (h *TermHub) Kill(root bool) {
	h.mu.Lock()
	s := h.sess[root]
	delete(h.sess, root)
	h.mu.Unlock()
	if s != nil {
		syscall.Kill(-s.cmd.Process.Pid, syscall.SIGHUP)
		s.pty.Close()
	}
}

func (h *TermHub) start(root bool, cols, rows int) (*termSession, error) {
	shell := loginShell()
	var cmd *exec.Cmd
	if root {
		// sudo asks for the password in the terminal itself and remembers it for this terminal.
		cmd = exec.Command("sudo", "-i")
	} else {
		cmd = exec.Command(shell, "-l")
	}
	cmd.Dir = home()
	cmd.Env = append(sessionEnv(), "TERM=xterm-256color", "COLORTERM=truecolor", "FALCON_REMOTE=1")
	f, err := pty.StartWithSize(cmd, &pty.Winsize{Cols: uint16(cols), Rows: uint16(rows)})
	if err != nil {
		return nil, err
	}
	s := &termSession{cmd: cmd, pty: f, done: make(chan struct{}), lastSeen: time.Now(), root: root}
	go func() {
		data := make([]byte, 32<<10)
		for {
			n, err := f.Read(data)
			if n > 0 {
				s.mu.Lock()
				s.buf = append(s.buf, data[:n]...)
				if len(s.buf) > scrollKeep {
					s.buf = s.buf[len(s.buf)-scrollKeep:]
				}
				c := s.client
				s.mu.Unlock()
				if c != nil {
					s.writeMu.Lock()
					c.WriteMessage(websocket.BinaryMessage, data[:n])
					s.writeMu.Unlock()
				}
			}
			if err != nil {
				break
			}
		}
		cmd.Wait()
		close(s.done)
		h.mu.Lock()
		if h.sess[root] == s {
			delete(h.sess, root)
		}
		h.mu.Unlock()
	}()
	return s, nil
}

type termMsg struct {
	T    string `json:"t"`
	D    string `json:"d"`
	Cols int    `json:"c"`
	Rows int    `json:"r"`
}

// Serve attaches a websocket to the user or the root shell, starting it when none runs.
// Both can run at once, so switching between them keeps each where it was.
func (h *TermHub) Serve(c *websocket.Conn, root bool, cols, rows int, fresh bool) {
	defer c.Close()
	if root && !h.app.config().TerminalRoot {
		c.WriteMessage(websocket.TextMessage, []byte(`{"error":`+jsonString(tr("The root terminal is turned off in the settings."))+`}`))
		return
	}
	if cols < 10 || cols > 500 {
		cols = 80
	}
	if rows < 5 || rows > 300 {
		rows = 24
	}
	if fresh {
		h.Kill(root)
	}
	h.mu.Lock()
	s := h.sess[root]
	if s == nil {
		var err error
		s, err = h.start(root, cols, rows)
		if err != nil {
			h.mu.Unlock()
			c.WriteMessage(websocket.TextMessage, []byte(`{"error":`+jsonString(err.Error())+`}`))
			return
		}
		h.sess[root] = s
	}
	h.mu.Unlock()

	s.mu.Lock()
	if old := s.client; old != nil {
		old.Close()
	}
	s.client = c
	backlog := append([]byte(nil), s.buf...)
	s.mu.Unlock()
	pty.Setsize(s.pty, &pty.Winsize{Cols: uint16(cols), Rows: uint16(rows)})
	s.writeMu.Lock()
	c.WriteMessage(websocket.TextMessage, []byte(`{"root":`+map[bool]string{true: "true", false: "false"}[root]+`}`))
	if len(backlog) > 0 {
		c.WriteMessage(websocket.BinaryMessage, backlog)
	}
	s.writeMu.Unlock()

	go func() {
		<-s.done
		s.writeMu.Lock()
		c.WriteMessage(websocket.TextMessage, []byte(`{"exit":true}`))
		s.writeMu.Unlock()
		c.Close()
	}()
	for {
		_, data, err := c.ReadMessage()
		if err != nil {
			break
		}
		var m termMsg
		if json.Unmarshal(data, &m) != nil {
			continue
		}
		switch m.T {
		case "i":
			s.pty.Write([]byte(m.D))
		case "r":
			if m.Cols >= 10 && m.Rows >= 5 {
				pty.Setsize(s.pty, &pty.Winsize{Cols: uint16(m.Cols), Rows: uint16(m.Rows)})
			}
		case "p":
			s.writeMu.Lock()
			c.WriteMessage(websocket.TextMessage, []byte(`{"pong":true}`))
			s.writeMu.Unlock()
		}
	}
	s.mu.Lock()
	if s.client == c {
		s.client = nil
		s.lastSeen = time.Now()
	}
	s.mu.Unlock()
}

func jsonString(s string) string {
	b, _ := json.Marshal(s)
	return string(b)
}

// loginShell is the user's shell from /etc/passwd, not whatever started this service.
func loginShell() string {
	data, _ := os.ReadFile("/etc/passwd")
	uid := strconv.Itoa(os.Getuid())
	for _, line := range strings.Split(string(data), "\n") {
		f := strings.Split(line, ":")
		if len(f) >= 7 && f[2] == uid && f[6] != "" {
			return f[6]
		}
	}
	if s := os.Getenv("SHELL"); s != "" {
		return s
	}
	return "/bin/bash"
}
