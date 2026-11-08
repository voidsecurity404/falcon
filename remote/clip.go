package main

import (
	"context"
	"errors"
	"os"
	"os/exec"
	"strings"
	"time"
)

// timed runs a session program that gives up after a while: a frozen clipboard owner
// or compositor must not hang the request, or the next ones waiting behind it.
func timed(limit time.Duration, name string, args ...string) *exec.Cmd {
	ctx, cancel := context.WithTimeout(context.Background(), limit)
	time.AfterFunc(limit+time.Second, cancel)
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Env = sessionEnv()
	cmd.WaitDelay = time.Second
	return cmd
}

func wl(name string, args ...string) *exec.Cmd { return timed(5*time.Second, name, args...) }

func setClipboard(data []byte, mime string) error {
	if !hasSession() {
		return errors.New(tr("Nobody is logged in: the computer is at the login screen"))
	}
	// wl-copy forks a child that keeps serving the clipboard. Its output must not be a pipe,
	// or waiting for the command would last until something else is copied.
	file, err := os.CreateTemp(runtimeDir(), "clip-*")
	if err != nil {
		os.MkdirAll(runtimeDir(), 0o700)
		if file, err = os.CreateTemp(runtimeDir(), "clip-*"); err != nil {
			return err
		}
	}
	defer os.Remove(file.Name())
	defer file.Close()
	file.Write(data)
	file.Seek(0, 0)
	// In a scope of its own, so the clipboard outlives a restart of this service.
	cmd := wl("systemd-run", "--user", "--scope", "--quiet", "--collect", "--", "wl-copy", "--type", mime)
	if _, err := exec.LookPath("systemd-run"); err != nil {
		cmd = wl("wl-copy", "--type", mime)
	}
	cmd.Stdin = file
	if err := cmd.Run(); err != nil {
		return errors.New(tr("The clipboard could not be set") + ": " + err.Error())
	}
	return nil
}

func clipboardTypes() []string {
	out, err := wl("wl-paste", "--list-types").Output()
	if err != nil {
		return nil
	}
	return strings.Fields(string(out))
}

func clipboardText() (string, error) {
	if !hasSession() {
		return "", errors.New(tr("Nobody is logged in: the computer is at the login screen"))
	}
	for _, t := range clipboardTypes() {
		if strings.HasPrefix(t, "text/plain") || t == "UTF8_STRING" || t == "STRING" || t == "TEXT" {
			out, err := wl("wl-paste", "--no-newline", "--type", t).Output()
			return string(out), err
		}
	}
	return "", nil
}

func clipboardImage() ([]byte, string) {
	for _, t := range clipboardTypes() {
		if strings.HasPrefix(t, "image/") {
			out, err := wl("wl-paste", "--type", t).Output()
			if err == nil && len(out) > 0 {
				return out, t
			}
		}
	}
	return nil, ""
}

// clipboardSave keeps the one most useful form of what is on the clipboard.
func clipboardSave() ([]byte, string) {
	types := clipboardTypes()
	pick := ""
	for _, want := range []string{"image/png", "text/uri-list", "text/plain;charset=utf-8", "text/plain", "UTF8_STRING"} {
		for _, t := range types {
			if t == want && pick == "" {
				pick = t
			}
		}
	}
	if pick == "" && len(types) > 0 {
		pick = types[0]
	}
	if pick == "" {
		return nil, ""
	}
	out, err := wl("wl-paste", "--type", pick).Output()
	if err != nil {
		return nil, ""
	}
	return out, pick
}

func clipboardRestore(data []byte, mime string) {
	if mime == "" {
		wl("wl-copy", "--clear").Run()
		return
	}
	setClipboard(data, mime)
	// The history now holds the same row twice: drop the new copy, so it looks untouched.
	time.Sleep(250 * time.Millisecond)
	out, err := wl("cliphist", "list").Output()
	if err != nil {
		return
	}
	rows := strings.SplitN(string(out), "\n", 3)
	if len(rows) < 2 {
		return
	}
	_, first, _ := strings.Cut(rows[0], "\t")
	_, second, _ := strings.Cut(rows[1], "\t")
	if first != "" && first == second {
		cmd := wl("cliphist", "delete")
		cmd.Stdin = strings.NewReader(rows[0] + "\n")
		cmd.Run()
	}
}

// forgetNewestPicture removes the top cliphist row when it is a picture, the remote screenshot.
func forgetNewestPicture() {
	out, err := wl("cliphist", "list").Output()
	if err != nil {
		return
	}
	first, _, _ := strings.Cut(string(out), "\n")
	if !strings.Contains(first, "[[ binary data") || !strings.Contains(first, "png") {
		return
	}
	cmd := wl("cliphist", "delete")
	cmd.Stdin = strings.NewReader(first + "\n")
	cmd.Run()
}
