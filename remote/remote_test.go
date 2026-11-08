package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"sort"
	"strings"
	"sync"
	"testing"
	"time"
)

const testToken = "123456789:AAFakeTokenForLocalTestingOnly_abcdefghij"

func sign(t *testing.T, user int64, when time.Time) string {
	v := url.Values{"auth_date": {fmt.Sprint(when.Unix())}, "user": {fmt.Sprintf(`{"id":%d}`, user)}, "query_id": {"x"}}
	keys := []string{}
	for k := range v {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	lines := []string{}
	for _, k := range keys {
		lines = append(lines, k+"="+v.Get(k))
	}
	s := hmac.New(sha256.New, []byte("WebAppData"))
	s.Write([]byte(testToken))
	m := hmac.New(sha256.New, s.Sum(nil))
	m.Write([]byte(strings.Join(lines, "\n")))
	v.Set("hash", hex.EncodeToString(m.Sum(nil)))
	return v.Encode()
}

func TestInitData(t *testing.T) {
	if err := checkInitData(sign(t, 7, time.Now()), testToken, 7); err != nil {
		t.Fatalf("owner refused: %v", err)
	}
	if checkInitData(sign(t, 8, time.Now()), testToken, 7) == nil {
		t.Fatal("another user accepted")
	}
	if checkInitData(sign(t, 7, time.Now().Add(-48*time.Hour)), testToken, 7) == nil {
		t.Fatal("old data accepted")
	}
	bad := strings.Replace(sign(t, 7, time.Now()), "query_id=x", "query_id=y", 1)
	if checkInitData(bad, testToken, 7) == nil {
		t.Fatal("changed data accepted")
	}
	if checkInitData(sign(t, 7, time.Now()), "1:other", 7) == nil {
		t.Fatal("wrong token accepted")
	}
	if checkInitData("", testToken, 7) == nil || checkInitData(sign(t, 7, time.Now()), testToken, 0) == nil {
		t.Fatal("empty data or no owner accepted")
	}
}

// A fake Telegram: one message from a stranger and one from the owner, then the bot's replies are checked.
func TestBotReplies(t *testing.T) {
	var mu sync.Mutex
	sent := []map[string]any{}
	served := false
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		method := r.URL.Path[strings.LastIndex(r.URL.Path, "/")+1:]
		body, _ := io.ReadAll(r.Body)
		var params map[string]any
		json.Unmarshal(body, &params)
		mu.Lock()
		defer mu.Unlock()
		switch method {
		case "getMe":
			w.Write([]byte(`{"ok":true,"result":{"username":"test_bot"}}`))
		case "getUpdates":
			if served {
				time.Sleep(200 * time.Millisecond)
				w.Write([]byte(`{"ok":true,"result":[]}`))
				return
			}
			served = true
			w.Write([]byte(`{"ok":true,"result":[
				{"update_id":1,"message":{"message_id":1,"from":{"id":99},"chat":{"id":99,"type":"private"},"text":"hi"}},
				{"update_id":2,"message":{"message_id":2,"from":{"id":7},"chat":{"id":7,"type":"private"},"text":"/id"}},
				{"update_id":3,"message":{"message_id":3,"from":{"id":7},"chat":{"id":-5,"type":"group"},"text":"/start"}}]}`))
		default:
			params["method"] = method
			sent = append(sent, params)
			w.Write([]byte(`{"ok":true,"result":true}`))
		}
	}))
	defer srv.Close()
	apiBase = srv.URL
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	t.Setenv("XDG_STATE_HOME", t.TempDir())
	app := &App{cfg: Config{Owner: 7, NotifyBoot: false}, token: testToken}
	app.bot = NewBot(testToken)
	go app.botLoop()
	time.Sleep(time.Second)
	mu.Lock()
	defer mu.Unlock()
	replies := map[float64]string{}
	for _, p := range sent {
		if p["method"] == "sendMessage" {
			replies[p["chat_id"].(float64)] = p["text"].(string)
		}
	}
	if !strings.Contains(replies[99], "private computer") || strings.Contains(replies[99], "99") {
		t.Errorf("stranger got %q", replies[99])
	}
	if !strings.Contains(replies[7], "7") {
		t.Errorf("owner /id got %q", replies[7])
	}
	if _, ok := replies[-5]; ok {
		t.Error("answered in a group")
	}
	if app.bot.Username() != "test_bot" {
		t.Error("username not read")
	}
}
