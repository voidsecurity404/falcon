# Falcon: the spinning fastfetch logo (bin/falcon-fetch).
# config.fish turns the greeting into falcon_greeting, because CachyOS's own
# config, sourced there, defines fish_greeting after this file.
status is-interactive; or exit

function falcon_greeting
    if type -q falcon-fetch
        command falcon-fetch --shell $fish_pid
    else
        fastfetch
    end
end

function __falcon_fetch_stop --on-event fish_preexec --on-event fish_exit
    if test -e $XDG_RUNTIME_DIR/falcon-fetch/$fish_pid
        command falcon-fetch --stop --shell $fish_pid
    end
end

function __falcon_fetch_clear
    __falcon_fetch_stop
    commandline -f clear-screen
end

function __falcon_fetch_binds --on-event fish_prompt
    functions -e __falcon_fetch_binds
    bind ctrl-l __falcon_fetch_clear
    bind -M insert ctrl-l __falcon_fetch_clear 2>/dev/null
end
