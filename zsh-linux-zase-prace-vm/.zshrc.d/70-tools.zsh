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

    # Catppuccin Mocha colours, so fzf matches the prompt.
    export FZF_DEFAULT_OPTS="
        --height=40% --layout=reverse --border --info=inline
        --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8
        --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc
        --color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8
        --color=selected-bg:#45475a"

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

# --- kubectl -----------------------------------------------------------
(( $+commands[kubectl] )) && source <(kubectl completion zsh)

# --- starship ----------------------------------------------------------
# Last of the prompt-affecting inits so nothing else overwrites PROMPT.
(( $+commands[starship] )) && eval "$(starship init zsh)"
