package main

import (
	"bytes"
	"errors"
	"os/exec"
	"strings"
)

func wl(name string, args ...string) *exec.Cmd {
	cmd := exec.Command(name, args...)
	cmd.Env = sessionEnv()
	return cmd
}

func setClipboard(data []byte, mime string) error {
	if !hasSession() {
		return errors.New(tr("Nobody is logged in: the computer is at the login screen"))
	}
	cmd := wl("wl-copy", "--type", mime)
	cmd.Stdin = bytes.NewReader(data)
	if out, err := cmd.CombinedOutput(); err != nil {
		return errors.New(strings.TrimSpace(string(out) + " " + err.Error()))
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
