# niri-desk: pentest nishoni har bir terminalda $TARGET sifatida tayyor turadi.
__niri_desk_target() {
    local f="${XDG_STATE_HOME:-$HOME/.local/state}/niri-desk/target"
    if [ -r "$f" ]; then TARGET="$(cat "$f")"; export TARGET; fi
}
PROMPT_COMMAND="__niri_desk_target${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
