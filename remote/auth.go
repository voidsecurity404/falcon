package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"time"
)

// How long a Mini App opening stays valid. Telegram signs initData once, when the app opens.
const initDataLife = 24 * time.Hour

// checkInitData verifies Telegram's signature of the Mini App launch data and that the user is the owner.
// See https://core.telegram.org/bots/webapps#validating-data-received-via-the-mini-app
func checkInitData(raw, token string, owner int64) error {
	if raw == "" {
		return errors.New("open this page from the Telegram bot")
	}
	if token == "" || owner == 0 {
		return errors.New("the bot is not set up on the computer")
	}
	values, err := url.ParseQuery(raw)
	if err != nil {
		return errors.New("bad launch data")
	}
	hash := values.Get("hash")
	keys := make([]string, 0, len(values))
	for k := range values {
		if k != "hash" {
			keys = append(keys, k)
		}
	}
	sort.Strings(keys)
	lines := make([]string, len(keys))
	for i, k := range keys {
		lines[i] = k + "=" + values.Get(k)
	}
	secret := hmac.New(sha256.New, []byte("WebAppData"))
	secret.Write([]byte(token))
	mac := hmac.New(sha256.New, secret.Sum(nil))
	mac.Write([]byte(strings.Join(lines, "\n")))
	want := mac.Sum(nil)
	got, err := hex.DecodeString(hash)
	if err != nil || !hmac.Equal(want, got) {
		return errors.New("the signature does not match")
	}
	when, _ := strconv.ParseInt(values.Get("auth_date"), 10, 64)
	if time.Since(time.Unix(when, 0)) > initDataLife {
		return errors.New("this session is too old, reopen the app")
	}
	var user struct {
		ID int64 `json:"id"`
	}
	if json.Unmarshal([]byte(values.Get("user")), &user) != nil || user.ID != owner {
		return errors.New("this computer belongs to someone else")
	}
	return nil
}
