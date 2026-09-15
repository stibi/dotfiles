# Terminal light/dark detection.
#
# This is a *terminal* protocol, not an OS one, which is why it works over SSH
# with no side channel: the query travels down the same PTY as your keystrokes,
# the terminal on your laptop answers, and the reply comes back. herdr forwards
# both mechanisms to pane applications (since 0.8.0) and answers from its own
# cache, so the round trip measures ~1ms rather than a network hop.
#
# Two protocols, tried in that order:
#
#   1. CSI ? 996 n  — asks the terminal for its light/dark *preference*.
#      Answers CSI ? 997 ; 1 n (dark) or ; 2 n (light). Semantic, so there is
#      no luminance guessing. Same family as DECSET mode 2031.
#   2. OSC 11       — asks for the background colour and we judge luminance.
#      Older, more widely supported, and the reason for the drain below.
#
# All terminal I/O goes through /dev/tty rather than stdout. That is not
# incidental: writing the query to stdout means it lands in the pipe whenever
# this is called from a command substitution, so the terminal never sees it and
# detection silently falls back to the default.

typeset -g TERM_APPEARANCE=dark
typeset -g _appearance_result=

# A query whose reply arrives after we stop reading leaves bytes in the input
# buffer, which then land in the next command line. Always drain.
_appearance_drain() {
    while read -r -s -t 0 -k 1 -u $1 2>/dev/null; do :; done
}

_appearance_detect() {
    _appearance_result=
    [[ -o interactive ]] || return 1

    local ttyfd
    # Braces matter: `exec ... 2>/dev/null` would redirect the *shell's* stderr
    # to /dev/null permanently. Scoping it to a block keeps it to this open.
    { exec {ttyfd}<>/dev/tty } 2>/dev/null || return 1

    local old reply
    if ! old=$(stty -g <&$ttyfd 2>/dev/null); then
        { exec {ttyfd}>&- } 2>/dev/null
        return 1
    fi
    stty -echo <&$ttyfd 2>/dev/null

    # --- 1. semantic query ------------------------------------------------
    # The reply ends in 'n', which makes it a safe read delimiter.
    reply=
    print -nu $ttyfd $'\e[?996n'
    read -r -s -t 0.3 -d n -u $ttyfd reply 2>/dev/null
    _appearance_drain $ttyfd

    case $reply in
        *997\;1*) _appearance_result=dark  ;;
        *997\;2*) _appearance_result=light ;;
    esac

    # --- 2. OSC 11 background colour --------------------------------------
    # Queried BEL-terminated so a compliant reply is BEL-terminated too.
    # Reply looks like: ESC ] 11 ; rgb:1e1e/1e1e/2e2e BEL
    if [[ -z $_appearance_result ]]; then
        reply=
        print -nu $ttyfd $'\e]11;?\a'
        read -r -s -t 0.3 -d $'\a' -u $ttyfd reply 2>/dev/null
        _appearance_drain $ttyfd

        if [[ $reply == *rgb:* ]]; then
            local hex=${reply#*rgb:} r g b lum
            # Components may be 1-4 hex digits; the top two are the 8-bit value.
            r=$(( 16#${${hex%%/*}[1,2]} )); hex=${hex#*/}
            g=$(( 16#${${hex%%/*}[1,2]} )); hex=${hex#*/}
            b=$(( 16#${hex[1,2]} ))
            # Rec. 601 luma; brighter than mid-grey is a light background.
            lum=$(( (r * 299 + g * 587 + b * 114) / 1000 ))
            (( lum > 127 )) && _appearance_result=light || _appearance_result=dark
        fi
    fi

    stty "$old" <&$ttyfd 2>/dev/null
    { exec {ttyfd}>&- } 2>/dev/null

    [[ -n $_appearance_result ]]
}

_appearance_apply_zsh_highlighting() {
    local mode=$1 command_colour alias_colour error_colour path_colour
    local argument_colour comment_colour

    # The highlighting plugin is sourced later in 90-plugins.zsh. During the
    # initial appearance pass there is nothing to update yet; that file calls
    # this function once the plugin has created its style table. Subsequent
    # `appearance light|dark` calls update the live ZLE styles immediately.
    (( ${+ZSH_HIGHLIGHT_STYLES} )) || return 0

    if [[ $mode == light ]]; then
        command_colour='#40a02b'  # Latte green
        alias_colour='#179299'    # Latte teal
        error_colour='#d20f39'    # Latte red
        path_colour='#1e66f5'     # Latte blue
        argument_colour='#df8e1d' # Latte yellow
        comment_colour='#6c6f85'  # Latte subtext0
    else
        command_colour='#a6e3a1'  # Mocha green
        alias_colour='#94e2d5'    # Mocha teal
        error_colour='#f38ba8'    # Mocha red
        path_colour='#89b4fa'     # Mocha blue
        argument_colour='#f9e2af' # Mocha yellow
        comment_colour='#6c7086'  # Mocha overlay0
    fi

    ZSH_HIGHLIGHT_STYLES[command]="fg=$command_colour"
    ZSH_HIGHLIGHT_STYLES[builtin]="fg=$command_colour"
    ZSH_HIGHLIGHT_STYLES[function]="fg=$command_colour"
    ZSH_HIGHLIGHT_STYLES[alias]="fg=$alias_colour"
    ZSH_HIGHLIGHT_STYLES[unknown-token]="fg=$error_colour"
    ZSH_HIGHLIGHT_STYLES[path]="fg=$path_colour,underline"
    ZSH_HIGHLIGHT_STYLES[single-quoted-argument]="fg=$argument_colour"
    ZSH_HIGHLIGHT_STYLES[double-quoted-argument]="fg=$argument_colour"
    ZSH_HIGHLIGHT_STYLES[comment]="fg=$comment_colour"
}

_appearance_apply() {
    local mode=$1 flavour
    [[ $mode == light ]] && flavour=latte || flavour=mocha
    typeset -g TERM_APPEARANCE=$mode

    # --- k9s ---------------------------------------------------------------
    export K9S_SKIN="catppuccin-${flavour}"

    # --- fzf ---------------------------------------------------------------
    # bg and fg stay at the terminal default (-1) on purpose: it keeps fzf
    # transparent to whatever the terminal is actually painting, so the popup
    # never sits on a stale background if detection was wrong or unavailable.
    if [[ $mode == light ]]; then
        export FZF_DEFAULT_OPTS="
            --height=40% --layout=reverse --border --info=inline
            --color=bg+:#ccd0da,bg:-1,spinner:#dc8a78,hl:#d20f39
            --color=fg:-1,header:#d20f39,info:#8839ef,pointer:#dc8a78
            --color=marker:#7287fd,fg+:#4c4f69,prompt:#8839ef,hl+:#d20f39
            --color=selected-bg:#bcc0cc"
    else
        export FZF_DEFAULT_OPTS="
            --height=40% --layout=reverse --border --info=inline
            --color=bg+:#313244,bg:-1,spinner:#f5e0dc,hl:#f38ba8
            --color=fg:-1,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc
            --color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8
            --color=selected-bg:#45475a"
    fi

    # --- starship ----------------------------------------------------------
    # starship picks its palette from the config file and has no env override,
    # so rather than maintain two near-identical configs that drift, derive one
    # by rewriting the single `palette =` line. Regenerated only when the
    # source is newer, so a normal startup costs one stat.
    local src="$HOME/.config/starship.toml"
    local gen="${XDG_CACHE_HOME:-$HOME/.cache}/starship/${flavour}.toml"
    if [[ -r $src ]]; then
        if [[ ! -f $gen || $src -nt $gen ]]; then
            mkdir -p "${gen:h}"
            sed "s/^palette = .*/palette = \"catppuccin_${flavour}\"/" "$src" >| "$gen"
        fi
        export STARSHIP_CONFIG="$gen"
    fi

    # --- zsh-syntax-highlighting ------------------------------------------
    _appearance_apply_zsh_highlighting "$mode"
}

# bat's own `--theme=auto` query misdetects the background through herdr. Keep
# the light/dark theme pair here, but choose the side from the terminal query
# that this file already performed successfully. The wrapper reads at call
# time, so `appearance light|dark` affects the next invocation immediately.
export BAT_THEME_DARK="Catppuccin Mocha"
export BAT_THEME_LIGHT="Catppuccin Latte"

if (( $+commands[batcat] )); then
    bat() {
        local arg

        # Preserve an explicit caller choice, in either accepted form.
        for arg in "$@"; do
            case $arg in
                --theme|--theme=*) command batcat "$@"; return ;;
            esac
        done

        command batcat --theme="${TERM_APPEARANCE:-dark}" "$@"
    }
fi

# Tig has custom colours but no terminal appearance detection. Select one of
# the Catppuccin configs per invocation so `appearance light|dark` takes effect
# immediately. An explicit TIGRC_USER remains an escape hatch for callers.
if (( $+commands[tig] )); then
    tig() {
        if (( ${+TIGRC_USER} )); then
            command tig "$@"
            return
        fi

        local flavour=mocha
        [[ $TERM_APPEARANCE == light ]] && flavour=latte
        TIGRC_USER="$HOME/.config/tig/catppuccin-${flavour}.tigrc" command tig "$@"
    }
fi

# Note the absence of a command substitution here — see the header.
if _appearance_detect; then
    _appearance_apply "$_appearance_result"
else
    _appearance_apply dark
fi

# hunk supports automatic light/dark detection, but cannot pair two chosen
# themes. The standalone launcher also works for non-shell callers such as the
# Herdr plugin; pass it this shell's cached result to avoid a second query.
if (( $+commands[hunk] )) && [[ -x $HOME/.local/bin/hunk-catppuccin ]]; then
    hunk() {
        HUNK_THEME_APPEARANCE=${TERM_APPEARANCE:-dark} \
            command "$HOME/.local/bin/hunk-catppuccin" "$@"
    }
fi

# Codex's `tui.theme` controls syntax highlighting (including fenced code),
# but a selection made with `/theme` is persisted as one fixed theme. Supply
# the matching Catppuccin flavour per launch instead, without rewriting
# ~/.codex/config.toml. Codex detects the terminal's general light/dark palette
# when its TUI starts, so an already-running session still needs to be resumed
# after the terminal appearance changes.
if (( $+commands[codex] )); then
    codex() {
        local theme=catppuccin-mocha
        [[ $TERM_APPEARANCE == light ]] && theme=catppuccin-latte
        command codex -c "tui.theme=\"$theme\"" "$@"
    }
fi

# Re-detect on demand, for when the OS theme changes mid-session. Live
# switching would need an async reader competing with zle for the tty, which is
# more trouble than it is worth; this is the manual escape hatch.
appearance() {
    case ${1:-} in
        dark|light) _appearance_apply "$1" ;;
        "")         if _appearance_detect; then
                        _appearance_apply "$_appearance_result"
                    else
                        print -ru2 -- "appearance: terminal did not answer; keeping $TERM_APPEARANCE"
                        return 1
                    fi ;;
        *)          print -ru2 -- "usage: appearance [dark|light]"; return 1 ;;
    esac
    print -r -- "appearance: $TERM_APPEARANCE"
}
