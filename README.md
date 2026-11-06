# Falcon

Falcon is a desktop for niri: small black panels, a numbered workspace strip, one island at the top and colors taken from the wallpaper. The panel, launcher and dashboard are written in Quickshell. The interface is available in English and Russian ([Русская версия](README.ru.md)).

> For a no-desktop CachyOS or Arch install. `install.sh` stops on Omarchy on purpose, because it conflicts with its hypr, kitty and GTK settings.

## Install

Install CachyOS with no desktop, log in on the tty as your normal user, then:

```bash
sudo pacman -S --needed git
git clone https://github.com/voidsecurity404/falcon.git
cd falcon
./install.sh --dry-run   # shows what would happen, changes nothing
./install.sh
sudo reboot
```

The installer adds packages, GPU drivers (Intel and AMD), Claude Code when your repositories have it, and turns on NetworkManager, Bluetooth and audio. It sets up the SDDM login screen, unless another display manager is already enabled or you pass `--no-login-manager`. If the login screen does not start, press `Ctrl+Alt+F2`, log in and fix it from there. NVIDIA drivers are not installed for you: on CachyOS run `sudo chwd -a`.

Existing configs are saved to `~/.local/state/falcon/backup-*`. `./install.sh --uninstall` restores them, turns SDDM off and leaves packages installed. Your own binds from `user.kdl` are kept in `~/.local/state/falcon/user.kdl` and come back on the next install.

## Language

Settings → Appearance → Language: Automatic, English or Русский. Automatic follows the system locale. Translations live in `~/.config/falcon/i18n-ru.json`.

## Shortcuts

`Mod` is the Super key. Full list: `Mod+Shift+/`.

| Shortcut | Action |
| --- | --- |
| `Mod+Return` | Terminal |
| `Mod+Space` | App menu from the bottom of the screen: type an app name, or `>` for commands. The red button beside the search field opens the big power menu in the middle of the screen: lock, sleep, log out, reboot and shut down |
| `Mod+V` | Clipboard history |
| `Mod+D` | Dashboard |
| `Mod+C` | Control center |
| `Mod+W` | Wallpaper and color |
| `Mod+F` | Focus mode |
| `Mod+O` | Overview (or move the pointer to the top left corner of the screen) |
| `Mod+,` | Settings |
| `` Mod+` `` | Scratchpad terminal (the session survives closing) |
| `Mod+S` | Sticky window: visible on every workspace and stays in place while you switch (the workspace slide is off while one is sticky). Press again to put it back among the columns |
| `Alt+Tab` | Recent windows spread like cards, each showing how the window last looked |
| `Mod+B` / `Mod+E` / `Mod+N` | Browser, files, notes: focus if open, otherwise launch |
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
| `Mod+Shift+G` | Hand control on or off |

## Dashboard

Click the clock. Two tabs, switched with `1`, `2` or `Tab`.

| Tab | Purpose |
| --- | --- |
| Today | The time made of living dots that flee from the pointer and tremble with the CPU load, the date and weather, CPU, memory, temperature, disk and battery, settings button |
| Music | Blurred, slowly moving cover in the background, colors taken from the cover, a spinning record, seekable progress bar, and a visualizer that follows the real sound. The sound is only measured on this computer |

## Desktop widgets

Thirty widgets can sit on the wallpaper: clocks, calendars, weather, system meters, music, a sticky note, a checklist, a Pomodoro timer, a quote of the day and Claude limits. To change them, right click the desktop and choose Edit widgets, or press `Mod+Shift+W`. In edit mode drag a widget, it snaps to a grid; the button in its corner changes the size and the cross removes it. Add widget in the bar below opens a gallery where every widget is shown live on your wallpaper, sorted by kind. Press one to put it on the desktop. Settings → Widgets turns them off, shows them on every workspace and changes their transparency. Each time you change the wallpaper, the widgets move to its calm parts, away from what the picture shows, and change their form: wide, tall or compact, for example hours over minutes or a record above the track. They keep their size setting. A layout you change by hand is remembered for that wallpaper and comes back with it. Settings → Widgets can limit this to the place only, or turn it off. The layout is stored in `~/.config/falcon/widgets.json`.

While music plays, sound waves move along the bottom of the desktop. They have a fixed place, and widgets stay above them. The sound is only measured on this computer. Settings → Widgets → Music turns them off and sets their style (bars, wave, line or dots), height, brightness, sensitivity, smoothness, thickness, direction and color.

Widgets and waves show through see-through windows such as the terminal, softened by the window's blur.


## Hand control

The webcam watches one hand and the pointer follows it. Settings → Hand control downloads what it needs once (MediaPipe, OpenCV and a hand model, about 550 MB, into `~/.local/share/falcon/handmouse`) and turns it on; `Mod+Shift+G` does too. The pictures are read on this computer and never saved. The camera is on only while hand control is on, and the panel shows the camera icon meanwhile.

| Gesture | Does |
| --- | --- |
| Move the hand | The pointer follows, smoothed so it stays still while the hand rests |
| Tap thumb to index finger | Click, twice for a double click |
| Hold thumb on index finger, or move while pinching | Drag until you let go |
| Tap thumb to middle finger, index straight | Right click |
| Index and middle up, move up or down | Scroll |
| Fist | The pointer stays where it is while the hand moves |
| Spread palm held still | Pause or resume, when turned on in the settings |

The settings page shows the camera with the hand drawn over it and the part of the picture that covers the screen. It sets that area, the smoothing, every gesture threshold, and whether the pointer goes to where the hand is or moves with it like a mouse. Calibrate shows a circle in each corner: point at it and hold still, and the corners become easier to reach. Buttons are let go when the hand leaves the picture. It drives a virtual mouse through `/dev/uinput`, so it needs write access to it.

## Claude limits

The Claude icon sits next to the keyboard layout. Click it for the 5-hour and weekly usage and the time left until each resets. While the popup, the widget gallery or the desktop widget is on screen, `falcon-claude-usage` fetches the numbers from Anthropic every 10 seconds using Claude Code's sign-in in `~/.claude/.credentials.json`, even when Claude Code is closed, and the popup counts down to the next fetch. This is an undocumented API, so it can stop working; the popup then shows how old the numbers are instead. Claude Code's status line also saves the limits while it runs. Add this to `~/.claude/settings.json` once:

```json
"statusLine": { "type": "command", "command": "~/.local/bin/falcon-claude-status", "refreshInterval": 5 }
```

## Things that look after themselves

- **Battery charge limit:** Settings → Battery and power, or the tile in the control center. Needs one setup with your password (`falcon-charge setup`). Laptops whose firmware has no limit do not show it. Undo: `falcon-charge setup --undo`.
- **Power mode follows the charger.** A mode you choose by hand stays until the charger changes.
- **System updates:** the panel shows how many wait. A click opens a terminal with the update, which asks before installing. Checking downloads no packages.
- **Timer:** `>timer 25`, `>timer 1:30`, `>timer 90s`, or `>pomodoro` in the app menu. Click it in the island to pause, right click to stop. It survives a restart and sleep, but it cannot wake the laptop.
- **Microphone and camera:** an icon on the panel while an app uses them. A click names the apps.
- **Clipboard pins:** `Ctrl+P` in `Mod+V` keeps up to 6 rows on top. They stay on disk until unpinned.
- **Wallpaper by itself:** a slideshow, or one picture for the day and one for the night, in Settings → Wallpaper.
- **Displays keep their settings** by display, not by port. A new display gets a toast that opens its settings. Mirroring is not offered, because niri has no mirror mode.

## Helper commands

- `falcon-session run|watch|save|restore`: windows come back after a reboot on their workspace and monitor, in their column, with their size, floating ones at their position, and terminals in their folder. Saved on every change. While they come back the screen stays covered by the wallpaper and a clock, so after login the desktop appears with everything already in place. Arguments are never replayed, and what is inside a window is up to the app.
- `falcon-backup export [file]`, `import file`: save settings to one file.
- `falcon-doctor`: checks programs, running services, config and permissions, and says what to fix.
- `falcon-sync [--check] [--pull]`: copies changed files from the repo to the live desktop, leaving generated files and user data alone.
- `falcon-login`: sets up the SDDM login screen, it asks for sudo.
- Lock screen: Settings → System chooses hyprlock or the shell's own lock screen. `qs -c Falcon ipc call desk lockPreview` shows the shell's one without locking, Esc closes it.
- Screen capture: `Mod+Shift+S` and `Print` freeze the screen and let you select an area or click a window. Left click copies and saves, right click opens the editor. The toolbar switches between screenshot, Google search, text, translation and recording. Esc closes it.
- Google search: the browser posts the selected picture directly to Google Lens and shows the results.
- Translation: `falcon-image-translate IMAGE OUT [--to LANG]` writes a copy of a picture with its text translated in place, and a window shows the result. The text goes to an online translation service (`translate-shell`).

## Configuration

The side panels can hug the screen's corners, which then look round, or float away from the edge: Settings → Panel → Panel shape.

Most things change from the `Mod+,` window and apply immediately: appearance, wallpaper, panel, widgets, windows, per-app rules, monitors, keyboard, mouse and touchpad, shortcuts, terminal and system. Reset to defaults is on the System page. If a value from that window is rejected, it is reverted and the reason is shown. If you edit `settings.json` by hand, the file is left as is, and no setting applies until you fix the value named in the error. From the command line: `falcon-set windows.gaps 8`.

| What | Where |
| --- | --- |
| All settings | `~/.config/falcon/settings.json` |
| Your own binds | `~/.config/niri/cfg/user.kdl` |
| Extra animation settings | `~/.config/niri/cfg/layout.kdl` |
| Wallpapers | `~/Pictures/Wallpapers`, videos for the live tab in its `Live` folder. Change it in Settings → Wallpaper folder |
| Screenshots | `Screenshots` inside your pictures folder (`xdg-user-dir PICTURES`) |

## Layout

```
config/niri/        niri config, split by topic
config/quickshell/  panel, island, dashboard, search, wallpaper picker
config/matugen/     templates that take colors from the wallpaper
config/hypr/        hyprlock and hypridle
config/falcon/   defaults, Russian catalog, emoji list
bin/                wallpaper, focus, recording, OCR and other scripts
wallpapers/         sample wallpapers
fonts/              Geist, Geist Mono and Unbounded (SIL OFL 1.1)
```

## Where the ideas came from

| Idea | Source |
| --- | --- |
| Per-window keyboard layout, marking the shared window | [niri docs](https://github.com/niri-wm/niri/tree/v26.04/docs/wiki) |
| Scratchpad terminal | [niri-scratchpad](https://github.com/gvolpe/niri-scratchpad) |
| Focus an app if it is open | [niri-ror](https://github.com/boomskats/niri-ror) |
| Sticky window | [nsticky](https://github.com/lonerOrz/nsticky), [niri-float-sticky](https://github.com/probeldev/niri-float-sticky) |
| Screenshot editing | [niri-screenshot-tools](https://codeberg.org/whenthesilly/niri-screenshot-tools) |
| Tray, notification history, caffeine mode | [Noctalia](https://github.com/noctalia-dev/noctalia-shell) |
| Calculator and windows in search, audio output, power buttons | [Dux Shell](https://github.com/duxlabs-dev/dux-shell) |

No code was copied from these projects, the ideas were rewritten.

Picture translation reads text with the `tessdata_fast` script models of the Tesseract project (Apache-2.0). `falcon-ocr-models` downloads them, about 200 MB.

## Status

`tests/run.py` runs the scenarios on CachyOS in VirtualBox. It closes windows and changes settings, so run it only on a test machine. It needs `ydotool`, `foot`, `ffmpeg` and `network-manager-applet`.

Not tested yet: automatic window restore at login, a second monitor, brightness, battery warnings, Wi-Fi, Bluetooth, touchpad, performance on a real GPU, screen sharing, logging in from the login screen, and the final step of the log out, reboot and shutdown buttons.
