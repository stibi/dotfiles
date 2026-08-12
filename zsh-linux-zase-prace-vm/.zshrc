# zsh config for the "zase-prace" Debian work VM.
#
# Deliberately NOT portable — this package targets exactly one machine.
# The macOS workstation keeps using the ../zsh package.
#
# Deployed with:  stow -v -t "$HOME" zsh-linux-zase-prace-vm

# Fragments are sourced in filename order; each one owns a single topic.
if [[ -d ${ZDOTDIR:-$HOME}/.zshrc.d ]]; then
    for _frag in ${ZDOTDIR:-$HOME}/.zshrc.d/*.zsh(N); do
        source "$_frag"
    done
    unset _frag
fi

# Machine-local secrets (API tokens, work-specific exports).
# Intentionally outside the dotfiles repo so it never gets committed.
[[ -r ~/.config/secrets.zsh ]] && source ~/.config/secrets.zsh
