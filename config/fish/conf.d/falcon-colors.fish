# Falcon: terminal tools draw with the terminal's 16 colors, which kitty takes
# from the wallpaper, so they change together with it.
status is-interactive; or exit

# bat and its users (fzf previews, git pagers) use the ANSI theme.
set -q BAT_THEME; or set -gx BAT_THEME ansi
# fzf: plain text, theme colors for matches, the pointer and borders.
set -q FZF_DEFAULT_OPTS; or set -gx FZF_DEFAULT_OPTS '--color=fg:-1,bg:-1,hl:4,fg+:15,bg+:0,hl+:12,info:6,prompt:4,pointer:5,marker:5,spinner:6,header:6,border:8,gutter:-1'
