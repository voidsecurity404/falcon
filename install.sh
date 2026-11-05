#!/usr/bin/env bash
# niri-desk installer. Works from a tty on a no-desktop CachyOS or Arch install.
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
state="$HOME/.local/state/niri-desk"
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
do_it() { if ((dry)); then printf '  [dry-run] %s\n' "$*"; else "$@"; fi; }

# Bu fayl va papkalar shu loyihaga tegishli: mavjudi avval zaxiraga olinadi.
targets=(
    .config/niri
    .config/quickshell/niri-desk
    .config/matugen
    .config/fastfetch/config.jsonc
    .config/fastfetch/brand.txt
    .config/kitty/kitty.conf
    .config/kitty/niri-desk-colors.conf
    .config/kitty/niri-desk-user.conf
    .config/hypr/hyprlock.conf
    .config/hypr/hypridle.conf
    .config/hypr/niri-desk-colors.conf
    .config/gtk-3.0/gtk.css
    .config/gtk-4.0/gtk.css
    .config/qt6ct
    .local/bin/niri-desk-claude-status
    .local/bin/niri-desk-claude-usage
    .local/bin/niri-desk-spectrum
    .local/bin/niri-desk-shot
    .local/bin/niri-desk-wallpaper
    .local/bin/niri-desk-widgets-place
    .local/bin/niri-desk-zen
    .local/bin/niri-desk-record
    .local/bin/niri-desk-ocr
    .local/bin/niri-desk-apply
    .local/bin/niri-desk-tr
    .local/bin/niri_desk_tr.py
    .config/hypr/niri-desk-lang.conf
    .local/bin/niri-desk-session
    .local/bin/niri-desk-translate
    .local/bin/niri-desk-backup
    .local/bin/niri-desk-shell
    .local/bin/niri-desk-set
    .local/bin/niri-desk-raise
    .local/bin/niri-desk-firefox
    .local/bin/niri-desk-login
    .local/bin/niri-desk-sddm-colors
    .local/bin/niri-desk-sync
    .local/bin/niri-desk-doctor
    .local/bin/niri-desk-scratch
    .local/bin/niri-desk-color
    .config/niri-desk/tmux.conf
    .config/niri-desk/emoji.json
    .config/niri-desk/defaults.json
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
    do_it rm -rf "$HOME/.local/share/fonts/niri-desk"
    do_it rm -rf "$HOME/.local/share/niri-desk"
    if ((dry == 0)) && [[ -f "$HOME/.bashrc" ]]; then sed -i '/niri-desk\/shell\.bash/d' "$HOME/.bashrc"; fi
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
This system is Omarchy. niri-desk conflicts with its hypr, kitty and GTK settings.
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
# Birinchi zaxira saqlanadi: --uninstall tizimni niri-desk'dan oldingi holatga qaytarishi kerak.
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
do_it rm -rf "$HOME/.config/niri" "$HOME/.config/quickshell/niri-desk" "$HOME/.config/matugen"
do_it mkdir -p "$HOME/.config/quickshell" "$HOME/.config/kitty" "$HOME/.config/hypr" "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0" "$HOME/.local/bin"
do_it cp -a "$root/config/niri" "$HOME/.config/niri"
if ((dry == 0)) && [[ -n "$user_kdl" ]]; then
    printf '%s\n' "$user_kdl" >"$HOME/.config/niri/cfg/user.kdl"
    rm -f "$saved_kdl"
fi
do_it cp -a "$root/config/quickshell/niri-desk" "$HOME/.config/quickshell/niri-desk"
do_it cp -a "$root/config/matugen" "$HOME/.config/matugen"
do_it cp -a "$root/config/kitty/." "$HOME/.config/kitty/"
do_it mkdir -p "$HOME/.config/fastfetch"
do_it cp "$root/config/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
do_it cp "$root/config/fastfetch/brand.txt" "$HOME/.config/fastfetch/brand.txt"
do_it cp -a "$root/config/hypr/." "$HOME/.config/hypr/"
do_it cp -a "$root/bin/." "$HOME/.local/bin/"

# Foydalanuvchi sozlamalari va fon rasmlari ustidan yozilmaydi.
do_it mkdir -p "$HOME/.config/niri-desk" "$HOME/Pictures/Wallpapers" "$HOME/Pictures/Wallpapers/Live" "$HOME/.local/share/fonts/niri-desk"
do_it cp "$root/config/niri-desk/tmux.conf" "$root/config/niri-desk/defaults.json" "$root/config/niri-desk/i18n-ru.json" "$root/config/niri-desk/emoji.json" "$HOME/.config/niri-desk/"
[[ -e "$HOME/.config/niri-desk/settings.json" ]] || do_it cp "$root/config/niri-desk/settings.json" "$HOME/.config/niri-desk/settings.json"
do_it cp -n "$root"/wallpapers/* "$HOME/Pictures/Wallpapers/"
do_it cp -a "$root"/fonts/. "$HOME/.local/share/fonts/niri-desk/"
if command -v fc-cache >/dev/null; then do_it fc-cache -f "$HOME/.local/share/fonts/niri-desk"; fi

# Niri, kitty va hypridle sozlamalari settings.json dan yoziladi.
if command -v niri >/dev/null && command -v python3 >/dev/null; then
    do_it "$HOME/.local/bin/niri-desk-apply"
fi
if command -v matugen >/dev/null; then
    # Avval tanlangan fon bo'lsa, ranglar o'shandan olinadi.
    image="$(readlink -f "$state/wallpaper" 2>/dev/null || true)"
    [[ -f "$image" ]] || image="$HOME/Pictures/Wallpapers/moviy-tun.jpg"
    say "Taking colors from the wallpaper: $(basename "$image")"
    do_it "$HOME/.local/bin/niri-desk-wallpaper" --colors "$image"
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
        do_it env NIRI_DESK_REPO="$root" "$HOME/.local/bin/niri-desk-login"
    fi
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
