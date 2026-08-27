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
    exec {ttyfd}<>/dev/tty 2>/dev/null || return 1

    local old reply
    if ! old=$(stty -g <&$ttyfd 2>/dev/null); then
        exec {ttyfd}>&- 2>/dev/null
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
    exec {ttyfd}>&- 2>/dev/null

    [[ -n $_appearance_result ]]
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
}

# bat needs no detection at all — `--theme=auto` is its default and it runs its
# own terminal query. It only needs to know which theme to use on each side.
# Setting BAT_THEME instead would pin it and defeat that.
export BAT_THEME_DARK="Catppuccin Mocha"
export BAT_THEME_LIGHT="Catppuccin Latte"

# Note the absence of a command substitution here — see the header.
if _appearance_detect; then
    _appearance_apply "$_appearance_result"
else
    _appearance_apply dark
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
