# niri-desk: pentest nishoni har bir terminalda $TARGET sifatida tayyor turadi.
function __niri_desk_target --on-event fish_prompt
    set -l state $XDG_STATE_HOME
    test -n "$state"; or set state $HOME/.local/state
    if test -r $state/niri-desk/target
        set -gx TARGET (cat $state/niri-desk/target)
    end
end
