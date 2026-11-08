package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"sync"
)

var (
	trOnce  sync.Once
	trTable map[string]string
)

// language follows appearance.language, then the system locale, like the rest of Falcon.
func language() string {
	for _, name := range []string{"settings.json", "defaults.json"} {
		data, err := os.ReadFile(filepath.Join(configDir(), name))
		if err != nil {
			continue
		}
		var s struct {
			Appearance struct {
				Language string `json:"language"`
			} `json:"appearance"`
		}
		if json.Unmarshal(data, &s) == nil && s.Appearance.Language != "" && s.Appearance.Language != "auto" {
			return s.Appearance.Language
		}
	}
	for _, key := range []string{"LC_ALL", "LC_MESSAGES", "LANG"} {
		if v := os.Getenv(key); v != "" {
			return v[:min(2, len(v))]
		}
	}
	return "en"
}

func translations() map[string]string {
	trOnce.Do(func() {
		trTable = map[string]string{}
		if language() != "ru" {
			return
		}
		data, err := os.ReadFile(filepath.Join(configDir(), "i18n-ru.json"))
		if err == nil {
			json.Unmarshal(data, &trTable)
		}
	})
	return trTable
}

// tr translates English text and fills {name} places: tr("Hi {who}", "who", "you").
func tr(text string, pairs ...string) string {
	if t, ok := translations()[text]; ok && t != "" {
		text = t
	}
	for i := 0; i+1 < len(pairs); i += 2 {
		text = strings.ReplaceAll(text, "{"+pairs[i]+"}", pairs[i+1])
	}
	return text
}
