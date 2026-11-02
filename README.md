# niri-desk

A desktop for niri: small black panels, a numbered workspace strip, one island at the top and colors taken from the wallpaper. The panel, launcher and dashboard are written in Quickshell. The interface is available in English and Russian ([Русская версия](README.ru.md)).

> For a no-desktop CachyOS or Arch install. `install.sh` stops on Omarchy on purpose, because it conflicts with its hypr, kitty and GTK settings.

## Install

Install CachyOS with no desktop, log in on the tty as your normal user, then:

```bash
sudo pacman -S --needed git
git clone https://github.com/voidsecurity404/niri-desk.git
cd niri-desk
./install.sh --dry-run   # shows what would happen, changes nothing
./install.sh
sudo reboot
```

The installer adds packages, GPU drivers (Intel and AMD), Claude Code when your repositories have it, and turns on NetworkManager, Bluetooth and audio. It sets up the greetd login screen, unless another display manager is already enabled or you pass `--no-login-manager`. If the login screen does not start, press `Ctrl+Alt+F2`, log in and fix it from there. NVIDIA drivers are not installed for you: on CachyOS run `sudo chwd -a`.

Existing configs are saved to `~/.local/state/niri-desk/backup-*`. `./install.sh --uninstall` restores them, turns greetd off and leaves packages installed.

For the AI chat, sign in once with `claude auth login`.

## Language

Settings → Appearance → Language: Automatic, English or Русский. Automatic follows the system locale. Translations live in `~/.config/niri-desk/i18n-ru.json`.

## Shortcuts

`Mod` is the Super key. Full list: `Mod+Shift+/`.

| Shortcut | Action |
| --- | --- |
| `Mod+Return` | Terminal |
| `Mod+Space` | Search: apps, clipboard, actions |
| `Mod+V` | Clipboard history |
| `Mod+D` | Dashboard |
| `Mod+C` | Control center |
| `Mod+W` | Wallpaper and color |
| `Mod+F` | Focus mode |
| `Mod+O` | Overview |
| `Mod+,` | Settings |
| `` Mod+` `` | Scratchpad terminal (the session survives closing) |
| `Mod+S` | Sticky window: visible on every workspace |
| `Alt+Tab` | Recent windows with live previews |
| `Mod+B` / `Mod+E` / `Mod+N` | Browser, files, notes: focus if open, otherwise launch |
| `Mod+Shift+B` | Burp Suite: focus if open, otherwise launch |
| `Mod+X` | Lock screen |
| `Mod+H` / `Mod+L` | Previous or next column |
| `Mod+J` / `Mod+K` | Next or previous workspace |
| `Mod+1..9` | Go to a workspace by number |
| `Mod+Ctrl+H/L` | Move a column |
| `Mod+Ctrl+1..9` | Move a column to another workspace |
| `Mod+R` | Column width: 1/3, 1/2, 2/3 |
| `Mod+M` | Maximize column |
| `Mod+Shift+F` | Fullscreen |
| `Mod+Q` | Close window |
| `Mod+Shift+S`, `Print` | Screenshot |
| `Mod+Shift+R` | Record screen |
| `Mod+P` | Copy text from screen |
| `Mod+Alt+P` | Translate a screen area |

## Search

| Type | Result |
| --- | --- |
| `kit` | Apps, open windows, clipboard and actions |
| `2+2*3` or `=2^10` | Calculator, Enter copies the result |
| `>nmap -sV 10.10.11.42` | Runs the command in a terminal |
| `?sql injection` | Web search |
| `b64 text`, `b64d`, `url`, `urld`, `hex`, `hexd`, `md5`, `sha256`, `html`, `htmld` | Encodes or decodes, Enter copies |
| `jwt token` | Decodes JWT header and payload, does not verify the signature |
| `hashid hash` | Guesses the hash type from its length and shape |
| `/password` | Finds files in your home folder, hidden files excluded |
| `;rev` | Snippet: fills in `{target}`, `{lhost}`, `{lport}` |
| `@pentest` | Opens a work profile |
| `target 10.10.11.42` | Sets the pentest target, available as `$TARGET` in terminals |
| `hosts box.htb` | Adds the name with the target IP to `/etc/hosts`, the terminal asks for the password |

Words typed on the wrong keyboard layout are found too: `лшеен` → `kitty`.

## Dashboard

Click the clock. Four tabs, switched with `1`–`4` or `Tab`.

| Tab | Purpose |
| --- | --- |
| Today | Time, weather, focus timer, calendar |
| Status | Music, CPU, RAM, disk, battery |
| Lab | Target, ports, VPN, quick scan, evidence collection, notes for this target (`~/Pentest/<target>/notes.md`) |
| AI | Chat with Claude |

## AI chat

With a Claude subscription, the chat runs through Claude Code: install it and sign in with `claude auth login`, no API key needed. Usage counts toward your subscription limits, shared with your other Claude Code work. The chat runs with no tools, so it cannot read files or run commands.

To use an API key instead, choose it in Settings → AI → Connection and enter the key. It is written to `~/.config/niri-desk/secrets/anthropic-key`, readable only by you and excluded from backups, and the official `anthropic` SDK from `~/.local/share/niri-desk/venv` is used. API usage is billed separately. With Automatic, Claude Code is used when the `claude` command is found.

The default model is `claude-opus-5-5`, and you can choose another in Settings. Messages and the current target IP are sent to Anthropic. The chat is stored in `~/.local/state/niri-desk/ai-history.json`.

## Lists you edit as files

`~/.config/niri-desk/profiles.json`: work profiles. `workspace` numbers set the order: niri keeps no empty workspaces, so if a number is skipped, windows are placed consecutively.

`~/.config/niri-desk/snippets.json`: snippets. `"run": true` runs in a terminal, otherwise the text is copied. If the target or IP is empty, nothing runs and the text is only copied.

## Helper commands

- `niri-desk-session save|restore`: restore windows. Saved every minute, restored at login. Arguments are never replayed, so a terminal opens empty.
- `niri-desk-backup export [file]`, `import file`: save settings, profiles and snippets to one file.
- `niri-desk-translate`: the text is sent to an online translation service (`translate-shell`).

## Configuration

Most things change from the `Mod+,` window and apply immediately: appearance, windows, per-app rules, panel, keyboard, shortcuts, monitors, AI and system. If a value does not pass `niri validate`, the previous setting stays. From the command line: `niri-desk-set windows.gaps 8`.

| What | Where |
| --- | --- |
| All settings | `~/.config/niri-desk/settings.json` |
| Your own binds | `~/.config/niri/cfg/user.kdl` |
| Extra animation settings | `~/.config/niri/cfg/layout.kdl` |
| Wallpapers | `~/Pictures/Wallpapers` |

Set `vpn.up` and `vpn.down` in `settings.json` to enable the shield button in the control center, for example `nmcli con up htb` and `nmcli con down htb`.

## Layout

```
config/niri/        niri config, split by topic
config/quickshell/  panel, island, dashboard, search, wallpaper picker
config/matugen/     templates that take colors from the wallpaper
config/hypr/        hyprlock and hypridle
config/niri-desk/   defaults, Russian catalog, profiles, snippets
bin/                wallpaper, focus, recording, OCR, lab and other scripts
wallpapers/         sample wallpapers
fonts/              Geist and Geist Mono (SIL OFL 1.1)
```

## Where the ideas came from

| Idea | Source |
| --- | --- |
| Alt+Tab, per-window keyboard layout, marking the shared window | [niri docs](https://github.com/niri-wm/niri/tree/v26.04/docs/wiki) |
| Scratchpad terminal | [niri-scratchpad](https://github.com/gvolpe/niri-scratchpad) |
| Focus an app if it is open | [niri-ror](https://github.com/boomskats/niri-ror) |
| Sticky window | [nsticky](https://github.com/lonerOrz/nsticky), [niri-float-sticky](https://github.com/probeldev/niri-float-sticky) |
| Screenshot editing | [niri-screenshot-tools](https://codeberg.org/whenthesilly/niri-screenshot-tools) |
| Tray, notification history, caffeine mode | [Noctalia](https://github.com/noctalia-dev/noctalia-shell) |
| Calculator and windows in search, audio output, power buttons | [Dux Shell](https://github.com/duxlabs-dev/dux-shell) |

No code was copied from these projects, the ideas were rewritten.

## Status

`tests/run.py` runs the scenarios on CachyOS in VirtualBox, results are in `tests/REPORT.md`. It closes windows and changes settings, so run it only on a test machine. It needs `ydotool`, `foot`, `ffmpeg` and `network-manager-applet`.

Not tested yet: the AI chat with a real API key (the Claude Code path was checked with a real subscription), automatic window restore at login, a second monitor, brightness, battery warnings, Wi-Fi, Bluetooth, touchpad, performance on a real GPU, screen sharing, logging in from the login screen, and the final step of the log out, reboot and shutdown buttons.
