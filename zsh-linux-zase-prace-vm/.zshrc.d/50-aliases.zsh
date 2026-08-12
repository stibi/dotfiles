# Aliases.
#
# Debian names two of these binaries differently from upstream:
#   bat -> batcat, fd -> fdfind
# so they get aliased back to the names used everywhere else.

alias grep='grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn}'
alias g="grep"
alias gi="grep -i"
alias -g G='| grep -i'

alias reload="exec zsh"
alias svim="sudo nvim"
alias vim=nvim
alias v=nvim

alias genpass='openssl rand -base64 16'
alias fuck='sudo $(fc -ln -1)'
alias p="ping -c5 www.google.com"

# eza in place of ls, keeping the classic short aliases.
if (( $+commands[eza] )); then
    alias ls='eza --group-directories-first'
    alias ll='eza -l --group-directories-first --git'
    alias la='eza -la --group-directories-first --git'
    alias lt='eza --tree --level=2 --group-directories-first'
else
    alias ls='ls --color=auto'
    alias ll='ls -l'
    alias la='ls -la'
fi

(( $+commands[batcat] )) && alias bat='batcat' && alias cat='batcat --plain'
(( $+commands[fdfind] )) && alias fd='fdfind'

# Terraform / OpenTofu
alias tf='terraform'
alias tg='terragrunt'
alias ti='terraform import'

# Kubernetes — only wire these up if the tools are actually installed,
# otherwise the aliases just produce confusing "command not found".
if (( $+commands[kubectl] )); then
    alias k=kubectl
    alias ku=kubectl
fi
(( $+commands[kubecolor] )) && alias kubectl=kubecolor && compdef kubecolor=kubectl
(( $+commands[kubie] ))     && alias ki=kubie

# Debian package management
alias aptup='sudo apt update && sudo apt upgrade'
alias apti='sudo apt install'
alias apts='apt search'

# Systemd
alias sc='sudo systemctl'
alias scu='systemctl --user'
alias jc='sudo journalctl'
