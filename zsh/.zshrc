#setopt histignorealldups sharehistory
setopt autocd autopushd pushdignoredups
unsetopt beep

# brew install findutils
export PATH="$(brew --prefix)/opt/findutils/libexec/gnubin:$PATH"
# https://formulae.brew.sh/formula/coreutils
export PATH="${HOMEBREW_PREFIX}/opt/coreutils/libexec/gnubin:$PATH"
# any local .venv/bin should go first
export PATH="$(pwd)/.venv/bin:${PATH}"
export PATH="/opt/homebrew/bin:${PATH}"
export PATH="/opt/homebrew/opt/libpq/bin:/opt/homebrew/opt/mysql-client/bin:$PATH:$HOME/bin:$HOME/.local/bin:$HOME/.krew/bin"
export PATH="${PATH}:/Users/stibi/go/bin"

# see https://asdf-vm.com/guide/upgrading-to-v0-16.html
export ASDF_DATA_DIR="/Users/stibi/.asdf"
export PATH="$ASDF_DATA_DIR/shims:$PATH"

alias vim=nvim
export EDITOR=vim
export USE_GKE_GCLOUD_AUTH_PLUGIN=True
export STARSHIP_CONFIG=~/.config/starship.toml

# to make ansible happy
# https://github.com/ansible/ansible/issues/76322
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES

# Use emacs keybindings even if our EDITOR is set to vi
bindkey -e

# Use modern completion system
if type brew &>/dev/null; then
  
  FPATH=$(brew --prefix)/share/zsh-completions:$(brew --prefix)/share/zsh/site-functions:$FPATH

  #autoload -Uz compinit
  #compinit
fi

autoload -Uz compinit
compinit

zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete _correct _approximate
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' menu select=2
#eval "$(dircolors -b)"
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=* l:|=*'
zstyle ':completion:*' menu select=long
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true

zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'
# https://github.com/keis/git-fixup#tab-completion
zstyle ':completion:*:*:git:*' user-commands fixup:'Create a fixup commit'

if [[ -d ~/.zshrc.d ]]; then
    for file in ~/.zshrc.d/*.zsh; do
        source "$file"
    done
    unset file
fi

#source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

PATH="/home/stibi/perl5/bin${PATH:+:${PATH}}"; export PATH;
PERL5LIB="/home/stibi/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"; export PERL5LIB;
PERL_LOCAL_LIB_ROOT="/home/stibi/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"; export PERL_LOCAL_LIB_ROOT;
PERL_MB_OPT="--install_base \"/home/stibi/perl5\""; export PERL_MB_OPT;
PERL_MM_OPT="INSTALL_BASE=/home/stibi/perl5"; export PERL_MM_OPT;

# +---------+
# | SCRIPTS |
# +---------+

# ?? proc tomu davam priponu suffix .zsh?
source ~/bin/scripts.zsh
source ~/bin/fzf-workflows.zsh

eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
eval "$(direnv hook zsh)"
source ~/bin/current-dir-in-iterm-tab-title.sh

source <(kubectl completion zsh)

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export PATH="/opt/homebrew/opt/flux@2.6/bin:$PATH"

# Local secrets (API keys etc.) — not tracked in dotfiles.
[ -f ~/.config/secrets.zsh ] && source ~/.config/secrets.zsh
