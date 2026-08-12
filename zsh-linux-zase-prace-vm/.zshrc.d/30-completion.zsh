# Completion system.

# Debian ships plenty of completions in /usr/share/zsh/vendor-completions,
# which is already on the default fpath.

autoload -Uz compinit

# Rebuild the dump at most once a day; on the other startups just load it.
# Keeps shell start fast without going stale after an apt install.
_zcompdump="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
mkdir -p "${_zcompdump:h}"
if [[ -n ${_zcompdump}(#qN.mh-24) ]]; then
    compinit -C -d "$_zcompdump"
else
    compinit -d "$_zcompdump"
fi
unset _zcompdump

zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete _correct _approximate
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' menu select=2
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true

# Case-insensitive, then partial-word, then substring matching.
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=* l:|=*'

# Colourise the completion menu the same way ls colours output.
eval "$(dircolors -b)"
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

# Make `kill <TAB>` genuinely useful.
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

# Don't offer the file you're already editing, etc.
zstyle ':completion:*:(rm|kill|diff):*' ignore-line other
