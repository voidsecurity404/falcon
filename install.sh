#!/usr/bin/env bash
# Falcon installer. Works from a tty on a no-desktop CachyOS or Arch install.
#
#   ./install.sh                    packages, drivers, services, login screen and configs
#   ./install.sh --dry-run          shows what would happen, changes nothing
#   ./install.sh --no-packages      configs only: no packages, services or login screen
#   ./install.sh --no-login-manager does not set up the SDDM login screen
#   ./install.sh --uninstall        restores previous configs from backup
#   ./install.sh --yes              does not prompt when installing packages
#   ./install.sh --force            allows running on Omarchy (not recommended)
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
state="$HOME/.local/state/falcon"
manifest="$state/backup-manifest"
saved_kdl="$state/user.kdl"
stamp="$(date +%Y%m%d-%H%M%S)"
backup="$state/backup-$stamp"

dry=0 packages=1 force=0 uninstall=0 login=1 yes=()
for arg in "$@"; do
    case "$arg" in
        --dry-run) dry=1 ;;
        --no-packages) packages=0 ;;
        --no-login-manager) login=0 ;;
        --force) force=1 ;;
        --yes) yes=(--noconfirm) ;;
        --uninstall) uninstall=1 ;;
        -h | --help) sed -n '2,10p' "$0" | cut -c3-; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

say() { printf '\033[1m»\033[0m %s\n' "$*"; }
((uninstall)) || say "Falcon"
do_it() { if ((dry)); then printf '  [dry-run] %s\n' "$*"; else "$@"; fi; }

# Bu fayl va papkalar shu loyihaga tegishli: mavjudi avval zaxiraga olinadi.
targets=(
    .config/niri
    .config/quickshell/falcon
    .config/matugen
    .config/fastfetch/config.jsonc
    .config/fastfetch/brand.txt
    .config/fastfetch/logos
    .config/fish/conf.d/falcon-fetch.fish
    .config/fish/conf.d/falcon-colors.fish
    .config/starship.toml
    .config/micro/colorschemes/falcon.micro
    .config/cava/config
    .config/spicetify/Themes/Falcon
    .config/spicetify/Extensions/falcon-live-colors.js
    .config/mpv
    .config/kitty/kitty.conf
    .config/kitty/falcon-colors.conf
    .config/kitty/falcon-user.conf
    .config/hypr/hyprlock.conf
    .config/hypr/hypridle.conf
    .config/hypr/falcon-colors.conf
    .config/gtk-3.0/gtk.css
    .config/gtk-4.0/gtk.css
    .config/qt6ct
    .config/kdeglobals
    .local/share/color-schemes/Falcon.colors
    .local/bin/falcon-claude-status
    .local/bin/falcon-claude-usage
    .local/bin/falcon-spectrum
    .local/bin/falcon-songrec
    .local/bin/falcon-lyrics
    .local/bin/falcon-game
    .local/bin/falcon-keysounds
    .local/bin/falcon-wallget
    .local/bin/falcon-keys
    .local/bin/falcon-fetch
    .local/bin/falcon-root-prompt
    .local/bin/falcon-shot
    .local/bin/falcon-wallpaper
    .local/bin/falcon-widgets-place
    .local/bin/falcon-zen
    .local/bin/falcon-record
    .local/bin/falcon-ocr
    .local/bin/falcon-apply
    .local/bin/falcon-tr
    .local/bin/falcon_tr.py
    .config/hypr/falcon-lang.conf
    .local/bin/falcon-session
    .local/bin/falcon-region
    .local/bin/falcon-region-windows
    .local/bin/falcon-lock-bg
    .local/bin/falcon-lens
    .local/bin/falcon-image-translate
    .local/bin/falcon-backup
    .local/bin/falcon-shell
    .local/bin/falcon-set
    .local/bin/falcon-raise
    .local/bin/falcon-firefox
    .local/bin/falcon-app-colors
    .local/bin/falcon-login
    .local/bin/falcon-boot
    .local/bin/falcon-sddm-colors
    .local/bin/falcon-sync
    .local/bin/falcon-doctor
    .local/bin/falcon-scratch
    .local/bin/falcon-color
    .local/bin/falcon-charge
    .local/bin/falcon-net
    .local/bin/falcon-updates
    .local/bin/falcon-privacy
    .local/bin/falcon-phone
    .local/bin/falcon-monitors
    .config/falcon/tmux.conf
    .config/falcon/emoji.json
    .local/bin/falcon-ocr-models
    .local/bin/falcon-ocr-read
    .local/bin/falcon-mpv-ui
    .local/bin/falcon-translate-models
    .local/bin/falcon-translate-local
    .config/falcon/defaults.json
    .local/bin/falcon-remote
    .local/bin/falcon-remote-build
    .config/systemd/user/falcon-remote.service
    .local/bin/archmarket
    .local/bin/falcon-archmarket-build
    .local/share/applications/archmarket.desktop
)

if ((uninstall)); then
    [[ -f "$manifest" ]] || { echo "Backup not found: $manifest" >&2; exit 1; }
    from="$(head -n 1 "$manifest")"
    # Shaxsiy klavishlar birinchi zaxirada yo'q: o'chirishdan oldin alohida saqlanadi.
    current_kdl="$HOME/.config/niri/cfg/user.kdl"
    if [[ -f "$current_kdl" ]] && ! cmp -s "$current_kdl" "$root/config/niri/cfg/user.kdl"; then
        do_it mkdir -p "$state"
        do_it cp "$current_kdl" "$saved_kdl"
        say "Your own binds were kept in $saved_kdl, the next install brings them back."
    fi
    for t in "${targets[@]}"; do
        do_it rm -rf "${HOME:?}/$t"
    done
    while IFS= read -r t; do
        [[ -n "$t" ]] || continue
        do_it mkdir -p "$(dirname "$HOME/$t")"
        do_it cp -a "$from/$t" "$HOME/$t"
    done < <(tail -n +2 "$manifest")
    do_it rm -rf "$HOME/.local/share/fonts/falcon"
    do_it rm -rf "$HOME/.local/share/falcon"
    if ((dry == 0)) && [[ -f "$HOME/.bashrc" ]]; then sed -i '/falcon\/shell\.bash/d' "$HOME/.bashrc"; fi
    if [[ -d /usr/share/plymouth/themes/falcon ]]; then
        do_it env FALCON_REPO="$root" "$root/bin/falcon-boot" --undo
    fi
    if [[ -e "$state/login-manager" ]] && ((dry == 0)); then
        sudo systemctl disable sddm.service || true
        sudo systemctl set-default "$(cat "$state/login-manager")" || true
        rm -f "$state/login-manager"
        say "The SDDM login screen was turned off, the system boots to a tty again."
    fi
    say "Previous configs restored. Packages were not removed, use pacman if you want them gone."
    exit 0
fi

# shellcheck source=/dev/null
. /etc/os-release
if [[ "${ID:-}" == omarchy ]] && ((force == 0)); then
    cat >&2 <<'MSG'
This system is Omarchy. falcon conflicts with its hypr, kitty and GTK settings.
The installation stopped and nothing was changed. Try it in a virtual machine.
MSG
    exit 1
fi
command -v pacman >/dev/null || { echo "This installer only works on pacman systems." >&2; exit 1; }
if ((EUID == 0)); then
    echo "Run this as your normal user, not root. It asks for sudo when needed." >&2
    exit 1
fi

# Bor bo'lsa ishlatiladi, yo'q bo'lsa jim o'tiladi: o'rnatish shu sababli to'xtamasin.
soft() { do_it "$@" || say "Skipped, it did not succeed: $*"; }

# Videokartaga mos drayverlar. NVIDIA alohida: CachyOS'da chwd bilan o'rnatiladi.
gpu_packages() {
    local vendor
    for vendor in /sys/class/drm/card*/device/vendor; do
        [[ -r "$vendor" ]] || continue
        case "$(cat "$vendor")" in
            0x8086) printf '%s\n' vulkan-intel intel-media-driver sof-firmware ;;
            0x1002) printf '%s\n' vulkan-radeon ;;
            0x10de) say "NVIDIA found: install its driver yourself (on CachyOS: sudo chwd -a). This path has not been tested." >&2 ;;
        esac
    done
}

if ((packages)); then
    mapfile -t list < <(grep -vE '^\s*(#|$)' "$root/packages.txt"; gpu_packages | sort -u)
    if ((login)) && [[ ! -e /etc/systemd/system/display-manager.service ]]; then
        list+=(sddm qt6-svg qt6-virtualkeyboard qt6-multimedia-ffmpeg)
    fi
    # Claude Code CachyOS omborida bor. Arch'da yo'q bo'lsa, oxirida ko'rsatma chiqadi.
    if ! command -v claude >/dev/null && pacman -Si claude-code >/dev/null 2>&1; then
        list+=(claude-code)
    fi
    # Song recognition. It is in CachyOS's repos, on plain Arch only in the AUR.
    if pacman -Si songrec >/dev/null 2>&1; then
        list+=(songrec)
    fi
    missing=()
    for p in "${list[@]}"; do
        pacman -Q "$p" >/dev/null 2>&1 || missing+=("$p")
    done
    if ((${#missing[@]})); then
        say "Packages to install (${#missing[@]}): ${missing[*]}"
        # Eski paket bazasidan qisman yangilanish tizimni buzishi mumkin, shuning uchun -Syu.
        do_it sudo pacman -Syu --needed "${yes[@]}" "${missing[@]}"
    else
        say "All packages are already installed"
    fi
fi

say "Backing up existing configs: $backup"
do_it mkdir -p "$state"
saved=()
for t in "${targets[@]}"; do
    if [[ -e "$HOME/$t" || -L "$HOME/$t" ]]; then
        do_it mkdir -p "$(dirname "$backup/$t")"
        do_it cp -a "$HOME/$t" "$backup/$t"
        saved+=("$t")
    fi
done
# Birinchi zaxira saqlanadi: --uninstall tizimni falcon'dan oldingi holatga qaytarishi kerak.
if ((dry == 0)) && [[ ! -f "$manifest" ]]; then
    { echo "$backup"; printf '%s\n' "${saved[@]}"; } >"$manifest"
fi

say "Copying configs"
# Qayta o'rnatishda foydalanuvchining o'z sozlamalari saqlanadi.
user_kdl=""
if [[ -f "$HOME/.config/niri/cfg/user.kdl" ]]; then
    user_kdl="$(cat "$HOME/.config/niri/cfg/user.kdl")"
elif [[ -f "$saved_kdl" ]]; then
    user_kdl="$(cat "$saved_kdl")"
fi
do_it rm -rf "$HOME/.config/niri" "$HOME/.config/quickshell/falcon" "$HOME/.config/matugen"
do_it mkdir -p "$HOME/.config/quickshell" "$HOME/.config/kitty" "$HOME/.config/hypr" "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0" "$HOME/.local/bin"
do_it cp -a "$root/config/niri" "$HOME/.config/niri"
if ((dry == 0)) && [[ -n "$user_kdl" ]]; then
    printf '%s\n' "$user_kdl" >"$HOME/.config/niri/cfg/user.kdl"
    rm -f "$saved_kdl"
fi
do_it cp -a "$root/config/quickshell/falcon" "$HOME/.config/quickshell/falcon"
do_it cp -a "$root/config/matugen" "$HOME/.config/matugen"
do_it cp -a "$root/config/kitty/." "$HOME/.config/kitty/"
do_it mkdir -p "$HOME/.config/fastfetch"
do_it cp "$root/config/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
do_it cp "$root/config/fastfetch/brand.txt" "$HOME/.config/fastfetch/brand.txt"
do_it rm -rf "$HOME/.config/fastfetch/logos"
do_it cp -a "$root/config/fastfetch/logos" "$HOME/.config/fastfetch/logos"
do_it mkdir -p "$HOME/.config/mpv"
do_it cp "$root/config/mpv/mpv.conf" "$root/config/mpv/input.conf" "$HOME/.config/mpv/"
do_it mkdir -p "$HOME/.config/fish/conf.d"
do_it cp "$root/config/fish/conf.d/falcon-fetch.fish" "$root/config/fish/conf.d/falcon-colors.fish" "$HOME/.config/fish/conf.d/"
# Terminal tools and other apps take the wallpaper colors (bin/falcon-app-colors).
do_it mkdir -p "$HOME/.config/micro/colorschemes" "$HOME/.config/cava"
do_it cp "$root/config/micro/colorschemes/falcon.micro" "$HOME/.config/micro/colorschemes/"
[[ -e "$HOME/.config/cava/config" ]] || do_it cp "$root/config/cava/config" "$HOME/.config/cava/config"
do_it mkdir -p "$HOME/.config/spicetify/Themes/Falcon" "$HOME/.config/spicetify/Extensions"
do_it cp "$root/config/spicetify/Themes/Falcon/user.css" "$HOME/.config/spicetify/Themes/Falcon/"
do_it cp "$root/config/spicetify/Extensions/falcon-live-colors.js" "$HOME/.config/spicetify/Extensions/"
# CachyOS config.fish o'z fish_greeting'ini conf.d dan keyin yozadi, shuning uchun
# aylanadigan logo uchun salomlashuv config.fish oxirida qayta belgilanadi.
fish_conf="$HOME/.config/fish/config.fish"
if ! grep -q falcon_greeting "$fish_conf" 2>/dev/null; then
    if ((dry)); then echo "  [dry-run] append fish_greeting to $fish_conf"
    else printf '\n# Falcon: spinning fastfetch logo (conf.d/falcon-fetch.fish)\nfunction fish_greeting\n    falcon_greeting\nend\n' >>"$fish_conf"; fi
fi
# Starship prompt (Nord Pills, the user's pick #5; colors are kitty's palette slots), turned on in fish and zsh once.
do_it cp "$root/config/starship/starship.toml" "$HOME/.config/starship.toml"
if ! grep -q "starship init fish" "$fish_conf" 2>/dev/null; then
    if ((dry)); then echo "  [dry-run] append starship init to $fish_conf"
    else printf '\n# Starship prompt (Nord Pills)\nif status is-interactive\n    starship init fish | source\n    # Transient prompt: finished commands keep only "❯ command"\n    function starship_transient_prompt_func\n        starship module character\n    end\n    enable_transience\nend\n' >>"$fish_conf"; fi
fi
zsh_conf="$HOME/.zshrc"
if [[ -e "$zsh_conf" ]] && ! grep -q "starship init zsh" "$zsh_conf"; then
    if ((dry)); then echo "  [dry-run] append starship init to $zsh_conf"
    else printf '\n# Starship prompt (Nord Pills) — turn off powerlevel10k from the CachyOS config first\n(( $+functions[prompt_powerlevel9k_teardown] )) && prompt_powerlevel9k_teardown\neval "$(starship init zsh)"\n' >>"$zsh_conf"
        cat >>"$zsh_conf" <<'ZSH'
# Transient prompt: finished commands keep only "❯ command"
autoload -Uz add-zle-hook-widget
_falcon_full_prompt=$PROMPT
_falcon_transient() { PROMPT='$(starship module character)'; RPROMPT=''; zle .reset-prompt }
_falcon_restore() { PROMPT=$_falcon_full_prompt }
add-zle-hook-widget line-finish _falcon_transient
precmd_functions+=(_falcon_restore)
ZSH
    fi
fi
do_it cp -a "$root/config/hypr/." "$HOME/.config/hypr/"
do_it cp -a "$root/bin/." "$HOME/.local/bin/"
# Root's bash (sudo su) gets the same Starship prompt.
command -v starship >/dev/null && soft sudo "$HOME/.local/bin/falcon-root-prompt"
# The Telegram remote control is a Go program, so it is built here. falcon-apply starts it once it is turned on.
do_it mkdir -p "$HOME/.config/systemd/user"
do_it cp "$root/config/systemd/falcon-remote.service" "$HOME/.config/systemd/user/"
soft systemctl --user daemon-reload
if command -v go >/dev/null; then
    say "Building the Telegram bot"
    soft env FALCON_REPO="$root" "$root/bin/falcon-remote-build"
fi
# Archmarket, the app store (Mod+I, also in the app menu), is a Rust program, so it is built here too.
if command -v cargo >/dev/null; then
    say "Building Archmarket"
    soft env FALCON_REPO="$root" "$root/bin/falcon-archmarket-build"
fi

# Foydalanuvchi sozlamalari va fon rasmlari ustidan yozilmaydi.
do_it mkdir -p "$HOME/.config/falcon" "$HOME/Pictures/Wallpapers" "$HOME/Pictures/Wallpapers/Live" "$HOME/.local/share/fonts/falcon"
do_it cp "$root/config/falcon/tmux.conf" "$root/config/falcon/defaults.json" "$root/config/falcon/i18n-ru.json" "$root/config/falcon/emoji.json" "$HOME/.config/falcon/"
[[ -e "$HOME/.config/falcon/settings.json" ]] || do_it cp "$root/config/falcon/settings.json" "$HOME/.config/falcon/settings.json"
do_it cp -n "$root"/wallpapers/* "$HOME/Pictures/Wallpapers/"
# The text readers of the picture translator, PaddleOCR and Tesseract's models. Without a network it
# fetches them at its first use.
soft "$root/bin/falcon-ocr-models"
soft "$root/bin/falcon-mpv-ui"
soft "$root/bin/falcon-app-colors" setup
# Folders open in Thunar, a GTK 3 app that takes new wallpaper colors while open.
command -v thunar >/dev/null && soft xdg-mime default thunar.desktop inode/directory
# The translator for when Google cannot be used, about 4 GB.
soft "$root/bin/falcon-translate-models"
do_it cp -a "$root"/fonts/. "$HOME/.local/share/fonts/falcon/"
if command -v fc-cache >/dev/null; then do_it fc-cache -f "$HOME/.local/share/fonts/falcon"; fi

# Niri, kitty va hypridle sozlamalari settings.json dan yoziladi.
if command -v niri >/dev/null && command -v python3 >/dev/null; then
    do_it "$HOME/.local/bin/falcon-apply"
fi
if command -v matugen >/dev/null; then
    # Avval tanlangan fon bo'lsa, ranglar o'shandan olinadi.
    image="$(readlink -f "$state/wallpaper" 2>/dev/null || true)"
    [[ -f "$image" ]] || image="$HOME/Pictures/Wallpapers/moviy-tun.jpg"
    say "Taking colors from the wallpaper: $(basename "$image")"
    do_it "$HOME/.local/bin/falcon-wallpaper" --colors "$image"
fi
if command -v dconf >/dev/null; then
    soft dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
    soft dconf write /org/gnome/desktop/interface/font-name "'Geist 11'"
fi
if command -v xdg-user-dirs-update >/dev/null; then
    soft xdg-user-dirs-update
fi

# Toza tizimda bu xizmatlar o'chiq bo'lishi mumkin.
if ((packages)); then
    for unit in NetworkManager bluetooth power-profiles-daemon; do
        if systemctl list-unit-files "$unit.service" 2>/dev/null | grep -q "^$unit"; then
            soft sudo systemctl enable --now "$unit.service"
        fi
    done
    for unit in pipewire.socket pipewire-pulse.socket wireplumber.service; do
        soft systemctl --user enable "$unit"
    done
    # Yorqinlikni o'zgartirish uchun.
    soft sudo usermod -aG video "$USER"
fi

# Kirish ekrani. Boshqa display manager bo'lsa tegilmaydi, tty'dan ishga tushmasin deb --now yo'q.
if ((packages && login)); then
    if [[ -e /etc/systemd/system/display-manager.service ]] && [[ "$(readlink -f /etc/systemd/system/display-manager.service)" != *sddm* ]]; then
        say "A display manager is already enabled, leaving it alone. Pick the niri session there."
    else
        say "Setting up the SDDM login screen"
        if [[ ! -e "$state/login-manager" ]] && ((dry == 0)); then
            mkdir -p "$state"
            systemctl get-default >"$state/login-manager"
        fi
        do_it env FALCON_REPO="$root" "$HOME/.local/bin/falcon-login"
    fi
fi

# Boot splash and boot menu name. Only where Plymouth is installed.
if ((packages)) && command -v plymouth-set-default-theme >/dev/null; then
    say "Putting Falcon on the boot screen"
    do_it env FALCON_REPO="$root" "$HOME/.local/bin/falcon-boot"
fi

# Only asks for sudo on a laptop whose battery has a charge limit.
if ((packages)) && compgen -G "/sys/class/power_supply/BAT*/charge_control_end_threshold" >/dev/null; then
    say "Setting up the battery charge limit"
    do_it "$HOME/.local/bin/falcon-charge" setup
fi

# The cable and Wi-Fi on one network took each other's traffic and the internet dropped.
if ((packages)) && command -v nmcli >/dev/null; then
    say "Keeping the internet from dropping"
    do_it "$HOME/.local/bin/falcon-net" setup
fi

if command -v niri >/dev/null; then
    do_it niri validate -c "$HOME/.config/niri/config.kdl"
fi

if ! command -v claude >/dev/null && ((dry == 0)); then
    say "Claude Code was not found. Install it and sign in to see Claude limits in the panel."
fi
say "Done. Backup: $backup"
if [[ -e "$state/login-manager" ]] || ((dry && packages && login)); then
    say "Reboot to get the login screen. If it fails, press Ctrl+Alt+F2 and log in on a tty."
else
    say "Pick the niri session on your login screen, or run niri-session from a tty."
fi
