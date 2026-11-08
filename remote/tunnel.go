package main

import (
	"bufio"
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"regexp"
	"time"
)

var tunnelURL = regexp.MustCompile(`https://[a-z0-9-]+\.trycloudflare\.com`)

// tunnel keeps a Cloudflare quick tunnel open. Telegram only opens Mini Apps over https, and a quick
// tunnel gives a fresh https address without an account or an open port. The address changes on every
// start, so the bot moves its menu button to the new one.
func (a *App) tunnel() {
	bin := os.Getenv("FALCON_CLOUDFLARED")
	if bin == "" {
		bin, _ = exec.LookPath("cloudflared")
	}
	if bin == "" {
		a.setState("no-cloudflared", tr("cloudflared is not installed"))
		return
	}
	wait := 3 * time.Second
	for {
		started := time.Now()
		a.runTunnel(bin)
		a.mu.Lock()
		a.url = ""
		a.mu.Unlock()
		a.updateState()
		if time.Since(started) > 5*time.Minute {
			wait = 3 * time.Second
		} else if wait < time.Minute {
			wait *= 2
		}
		time.Sleep(wait)
	}
}

func (a *App) runTunnel(bin string) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	cmd := exec.CommandContext(ctx, bin, "tunnel", "--no-autoupdate", "--protocol", "http2", "--url", fmt.Sprintf("http://127.0.0.1:%d", a.port))
	// Without a config of its own, so a named tunnel in ~/.cloudflared is never picked up.
	cmd.Dir = os.TempDir()
	cmd.Env = append(os.Environ(), "TUNNEL_ORIGIN_CERT=/dev/null")
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return
	}
	if err := cmd.Start(); err != nil {
		a.setState("error", err.Error())
		return
	}
	go func() {
		scan := bufio.NewScanner(stderr)
		for scan.Scan() {
			if url := tunnelURL.FindString(scan.Text()); url != "" {
				a.mu.Lock()
				changed := a.url != url
				a.url = url
				a.mu.Unlock()
				if changed {
					log.Printf("tunnel: %s", url)
					go a.whenReachable(ctx, url, cancel)
				}
			}
		}
	}()
	cmd.Wait()
	log.Print("tunnel closed")
}

// whenReachable announces the address once it answers, then restarts the tunnel if it stops answering.
func (a *App) whenReachable(ctx context.Context, url string, restart context.CancelFunc) {
	client := &http.Client{Timeout: 15 * time.Second}
	ok := func() bool {
		resp, err := client.Get(url + "/health")
		if err != nil {
			return false
		}
		resp.Body.Close()
		return resp.StatusCode == 200
	}
	for i := 0; i < 30 && !ok(); i++ {
		select {
		case <-ctx.Done():
			return
		case <-time.After(2 * time.Second):
		}
	}
	go a.announce(true)
	failures := 0
	for {
		select {
		case <-ctx.Done():
			return
		case <-time.After(time.Minute):
		}
		if ok() {
			failures = 0
		} else if failures++; failures >= 3 {
			log.Print("tunnel stopped answering, opening a new one")
			restart()
			return
		}
	}
}
