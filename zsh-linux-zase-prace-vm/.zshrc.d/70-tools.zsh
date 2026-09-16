# Third-party tool initialisation.
#
# Everything is guarded, so a missing tool degrades to "that feature is absent"
# rather than an error on every prompt.

# --- fzf ---------------------------------------------------------------
# ctrl-t (files), ctrl-r (history), alt-c (cd). fzf >= 0.48 can emit the
# zsh integration itself; the doc path is the fallback for older builds.
if (( $+commands[fzf] )); then
    if fzf --zsh >/dev/null 2>&1; then
        source <(fzf --zsh)
    else
        [[ -r /usr/share/doc/fzf/examples/key-bindings.zsh ]] && \
            source /usr/share/doc/fzf/examples/key-bindings.zsh
        [[ -r /usr/share/doc/fzf/examples/completion.zsh ]] && \
            source /usr/share/doc/fzf/examples/completion.zsh
    fi

    # FZF_DEFAULT_OPTS (including colours) is set in 15-appearance.zsh, which
    # picks the Catppuccin flavour matching the terminal's light/dark mode.

    # Use fd for traversal when available — respects .gitignore and is faster.
    if (( $+commands[fdfind] )); then
        export FZF_DEFAULT_COMMAND='fdfind --type f --hidden --follow --exclude .git'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
        export FZF_ALT_C_COMMAND='fdfind --type d --hidden --follow --exclude .git'
    fi
fi

# --- zoxide ------------------------------------------------------------
# `z <partial>` jumps to a frecent directory. Must come after compinit.
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"

# --- direnv ------------------------------------------------------------
(( $+commands[direnv] )) && eval "$(direnv hook zsh)"

# --- worktrunk ---------------------------------------------------------
# The wrapper lets `wt switch` change this shell's directory. Keep this here
# rather than running `wt config shell install`, which edits .zshrc itself.
(( $+commands[wt] )) && eval "$(wt config shell init zsh)"

# --- kubectl -----------------------------------------------------------
if (( $+commands[kubectl] )); then
    # Bypass the kubectl=kubecolor alias while generating the completion
    # function, then give kubecolor that function only after it exists.
    source <(command kubectl completion zsh)
    (( $+commands[kubecolor] )) && compdef _kubectl kubecolor
fi

# --- starship ----------------------------------------------------------
# Last of the prompt-affecting inits so nothing else overwrites PROMPT.
(( $+commands[starship] )) && eval "$(starship init zsh)"
