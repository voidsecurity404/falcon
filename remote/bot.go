package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"image"
	_ "image/gif"
	_ "image/jpeg"
	"image/png"
	"io"
	"log"
	"mime/multipart"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// apiBase can point at a fake server in tests.
var apiBase = envOr("FALCON_TELEGRAM_API", "https://api.telegram.org")

type Bot struct {
	token    string
	client   *http.Client
	mu       sync.Mutex
	username string
}

func NewBot(token string) *Bot {
	return &Bot{token: token, client: &http.Client{Timeout: 70 * time.Second}}
}

func (b *Bot) Username() string {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.username
}

type apiReply struct {
	OK          bool            `json:"ok"`
	Result      json.RawMessage `json:"result"`
	Description string          `json:"description"`
	ErrorCode   int             `json:"error_code"`
}

var errUnauthorized = errors.New("Telegram does not accept this token")

func (b *Bot) decode(resp *http.Response, out any) error {
	defer resp.Body.Close()
	var r apiReply
	if err := json.NewDecoder(resp.Body).Decode(&r); err != nil {
		return err
	}
	if !r.OK {
		if r.ErrorCode == 401 || r.ErrorCode == 404 {
			return errUnauthorized
		}
		return fmt.Errorf("telegram: %s", r.Description)
	}
	if out != nil {
		return json.Unmarshal(r.Result, out)
	}
	return nil
}

func (b *Bot) call(method string, params any, out any) error {
	body, _ := json.Marshal(params)
	resp, err := b.client.Post(apiBase+"/bot"+b.token+"/"+method, "application/json", bytes.NewReader(body))
	if err != nil {
		return errors.New(strings.ReplaceAll(err.Error(), b.token, "<token>"))
	}
	return b.decode(resp, out)
}

func (b *Bot) upload(method string, fields map[string]string, field, name string, data []byte) error {
	var buf bytes.Buffer
	w := multipart.NewWriter(&buf)
	for k, v := range fields {
		w.WriteField(k, v)
	}
	part, _ := w.CreateFormFile(field, name)
	part.Write(data)
	w.Close()
	resp, err := b.client.Post(apiBase+"/bot"+b.token+"/"+method, w.FormDataContentType(), &buf)
	if err != nil {
		return errors.New(strings.ReplaceAll(err.Error(), b.token, "<token>"))
	}
	return b.decode(resp, nil)
}

func (b *Bot) download(fileID string) ([]byte, string, error) {
	var f struct {
		FilePath string `json:"file_path"`
	}
	if err := b.call("getFile", map[string]any{"file_id": fileID}, &f); err != nil {
		return nil, "", err
	}
	resp, err := b.client.Get(apiBase + "/file/bot" + b.token + "/" + f.FilePath)
	if err != nil {
		return nil, "", errors.New("download failed")
	}
	defer resp.Body.Close()
	data, err := io.ReadAll(io.LimitReader(resp.Body, 50<<20))
	return data, f.FilePath, err
}

type tgUser struct {
	ID        int64  `json:"id"`
	FirstName string `json:"first_name"`
}

type tgMessage struct {
	MessageID int64   `json:"message_id"`
	From      *tgUser `json:"from"`
	Chat      struct {
		ID   int64  `json:"id"`
		Type string `json:"type"`
	} `json:"chat"`
	Text    string `json:"text"`
	Caption string `json:"caption"`
	Photo   []struct {
		FileID string `json:"file_id"`
	} `json:"photo"`
	Document *struct {
		FileID   string `json:"file_id"`
		FileName string `json:"file_name"`
		MimeType string `json:"mime_type"`
	} `json:"document"`
}

type tgUpdate struct {
	UpdateID int64      `json:"update_id"`
	Message  *tgMessage `json:"message"`
}

func (a *App) botLoop() {
	b := a.bot
	a.setState("connecting", "")
	for {
		var me struct {
			Username string `json:"username"`
		}
		err := b.call("getMe", map[string]any{}, &me)
		if err == nil {
			b.mu.Lock()
			b.username = me.Username
			b.mu.Unlock()
			break
		}
		if errors.Is(err, errUnauthorized) {
			a.setState("bad-token", err.Error())
			select {} // the watcher restarts us when the token changes
		}
		a.setState("offline", err.Error())
		time.Sleep(10 * time.Second)
	}
	log.Printf("bot @%s is up", b.Username())
	a.updateState()
	b.call("setMyCommands", map[string]any{"commands": []map[string]string{
		{"command": "start", "description": tr("Open the control panel")},
		{"command": "shot", "description": tr("Screenshot of the screen")},
		{"command": "clip", "description": tr("Text from the computer's clipboard")},
		{"command": "lock", "description": tr("Lock the screen")},
	}}, nil)
	go a.announce(true)

	var offset int64
	for {
		var updates []tgUpdate
		err := b.call("getUpdates", map[string]any{"offset": offset, "timeout": 50, "allowed_updates": []string{"message"}}, &updates)
		if err != nil {
			a.setState("offline", err.Error())
			time.Sleep(5 * time.Second)
			continue
		}
		a.updateState()
		for _, u := range updates {
			offset = u.UpdateID + 1
			if u.Message != nil && u.Message.From != nil {
				go a.handle(u.Message)
			}
		}
	}
}

// updateState reports ready once both the bot and the tunnel are up.
func (a *App) updateState() {
	cfg := a.config()
	switch {
	case a.bot == nil || a.bot.Username() == "":
		return
	case cfg.Owner == 0:
		a.setState("no-owner", "")
	case a.publicURL() == "":
		a.setState("tunnel", "")
	default:
		a.setState("ready", "")
	}
}

func (a *App) appButton(text string) map[string]any {
	return map[string]any{"inline_keyboard": [][]map[string]any{{{"text": text, "web_app": map[string]string{"url": a.publicURL()}}}}}
}

// announce points the owner's menu button at the current tunnel address, and says hello after a boot.
var announceMu sync.Mutex

func (a *App) announce(boot bool) {
	announceMu.Lock()
	defer announceMu.Unlock()
	if a.bot == nil || a.bot.Username() == "" {
		return
	}
	cfg := a.config()
	url := a.publicURL()
	a.updateState()
	if cfg.Owner == 0 || url == "" {
		return
	}
	err := a.bot.call("setChatMenuButton", map[string]any{
		"chat_id":     cfg.Owner,
		"menu_button": map[string]any{"type": "web_app", "text": tr("Computer"), "web_app": map[string]string{"url": url}},
	}, nil)
	if err != nil {
		log.Printf("menu button: %v", err)
	}
	if !boot || !cfg.NotifyBoot {
		return
	}
	bootID, _ := os.ReadFile("/proc/sys/kernel/random/boot_id")
	mark := filepath.Join(stateDir(), "remote-boot")
	if old, _ := os.ReadFile(mark); bytes.Equal(old, bootID) {
		return
	}
	host, _ := os.Hostname()
	text := "🟢 " + tr("{host} is on", "host", host) + "\n" + tr("Started {time}", "time", bootTime().Format("15:04"))
	if a.bot.call("sendMessage", map[string]any{"chat_id": cfg.Owner, "text": text, "reply_markup": a.appButton(tr("Open the control panel"))}, nil) == nil {
		os.MkdirAll(stateDir(), 0o755)
		os.WriteFile(mark, bootID, 0o644)
	}
}

func stateDir() string {
	if d := os.Getenv("XDG_STATE_HOME"); d != "" {
		return filepath.Join(d, "falcon")
	}
	return filepath.Join(home(), ".local/state/falcon")
}

func (a *App) reply(m *tgMessage, text string, markup any) {
	params := map[string]any{"chat_id": m.Chat.ID, "text": text}
	if markup != nil {
		params["reply_markup"] = markup
	}
	if err := a.bot.call("sendMessage", params, nil); err != nil {
		log.Printf("send: %v", err)
	}
}

func (a *App) react(m *tgMessage, emoji string) {
	a.bot.call("setMessageReaction", map[string]any{"chat_id": m.Chat.ID, "message_id": m.MessageID, "reaction": []map[string]string{{"type": "emoji", "emoji": emoji}}}, nil)
}

func (a *App) handle(m *tgMessage) {
	cfg := a.config()
	if m.Chat.Type != "private" {
		return
	}
	if cfg.Owner == 0 || m.From.ID != cfg.Owner {
		text := tr("This bot controls a private computer.")
		if cfg.Owner == 0 {
			text += "\n\n" + tr("Your Telegram ID: {id}", "id", fmt.Sprint(m.From.ID)) + "\n" + tr("If this is your computer, put this ID in Settings → Telegram bot.")
		}
		a.reply(m, text, nil)
		return
	}
	text := strings.TrimSpace(m.Text)
	command := ""
	if strings.HasPrefix(text, "/") {
		command = strings.SplitN(strings.TrimPrefix(strings.Fields(text)[0], "/"), "@", 2)[0]
	}
	switch {
	case command == "start" || command == "app":
		if a.publicURL() == "" {
			a.reply(m, tr("The connection is still starting. Try again in a few seconds."), nil)
			return
		}
		host, _ := os.Hostname()
		a.reply(m, "💻 "+host+"\n"+tr("Everything is in the panel: system, terminal, windows, processes and clipboard. Messages you send here go to the clipboard."), a.appButton(tr("Open the control panel")))
	case command == "id":
		a.reply(m, tr("Your Telegram ID: {id}", "id", fmt.Sprint(m.From.ID)), nil)
	case command == "shot":
		if !cfg.Screen {
			a.reply(m, tr("Screenshots are turned off in the settings."), nil)
			return
		}
		data, err := screenJPEG()
		if err != nil {
			a.reply(m, "⚠️ "+err.Error(), nil)
			return
		}
		if err := a.bot.upload("sendPhoto", map[string]string{"chat_id": fmt.Sprint(m.Chat.ID)}, "photo", "screen.jpg", data); err != nil {
			a.reply(m, "⚠️ "+err.Error(), nil)
		}
	case command == "clip":
		text, err := clipboardText()
		switch {
		case err != nil:
			a.reply(m, "⚠️ "+err.Error(), nil)
		case text == "":
			a.reply(m, tr("The clipboard has no text."), nil)
		default:
			if len(text) > 4000 {
				text = text[:4000] + "…"
			}
			a.reply(m, text, nil)
		}
	case command == "lock":
		if err := exec.Command("loginctl", "lock-sessions").Run(); err != nil {
			a.reply(m, "⚠️ "+err.Error(), nil)
			return
		}
		a.react(m, "👌")
	case command != "":
		a.reply(m, tr("Unknown command. Use /start."), nil)
	case len(m.Photo) > 0:
		a.fromPhoto(m, m.Photo[len(m.Photo)-1].FileID)
	case m.Document != nil:
		a.fromDocument(m)
	case text != "":
		if !cfg.ChatClipboard {
			a.reply(m, tr("Messages do not go to the clipboard: this is off in the settings."), nil)
			return
		}
		if err := setClipboard([]byte(m.Text), "text/plain;charset=utf-8"); err != nil {
			a.reply(m, "⚠️ "+err.Error(), nil)
			return
		}
		a.react(m, "👌")
	}
}

func (a *App) fromPhoto(m *tgMessage, fileID string) {
	data, _, err := a.bot.download(fileID)
	if err == nil {
		err = setClipboardImage(data)
	}
	if err != nil {
		a.reply(m, "⚠️ "+err.Error(), nil)
		return
	}
	a.react(m, "👌")
}

// setClipboardImage puts any picture on the clipboard as PNG, which every app can paste.
func setClipboardImage(data []byte) error {
	img, _, err := image.Decode(bytes.NewReader(data))
	if err != nil {
		return errors.New(tr("This picture could not be read"))
	}
	var buf bytes.Buffer
	png.Encode(&buf, img)
	return setClipboard(buf.Bytes(), "image/png")
}

func (a *App) fromDocument(m *tgMessage) {
	d := m.Document
	data, _, err := a.bot.download(d.FileID)
	if err != nil {
		a.reply(m, "⚠️ "+err.Error(), nil)
		return
	}
	if strings.HasPrefix(d.MimeType, "image/") && setClipboardImage(data) == nil {
		a.react(m, "👌")
		return
	}
	dir := downloadDir()
	name := filepath.Base(d.FileName)
	if name == "" || name == "." || name == "/" {
		name = "telegram-" + time.Now().Format("20060102-150405")
	}
	path := filepath.Join(dir, name)
	for i := 1; ; i++ {
		if _, err := os.Stat(path); os.IsNotExist(err) {
			break
		}
		ext := filepath.Ext(name)
		path = filepath.Join(dir, fmt.Sprintf("%s (%d)%s", strings.TrimSuffix(name, ext), i, ext))
	}
	os.MkdirAll(dir, 0o755)
	if err := os.WriteFile(path, data, 0o644); err != nil {
		a.reply(m, "⚠️ "+err.Error(), nil)
		return
	}
	setClipboard([]byte("file://"+path+"\r\n"), "text/uri-list")
	a.reply(m, "📁 "+tr("Saved: {path}", "path", strings.Replace(path, home(), "~", 1))+"\n"+tr("The file is on the clipboard, paste it in the file manager."), nil)
}

func downloadDir() string {
	out, err := exec.Command("xdg-user-dir", "DOWNLOAD").Output()
	if dir := strings.TrimSpace(string(out)); err == nil && dir != "" && dir != home() {
		return dir
	}
	return filepath.Join(home(), "Downloads")
}
