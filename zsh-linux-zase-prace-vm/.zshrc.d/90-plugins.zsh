# zsh plugins, installed from Debian packages.
#
# Ordering is load-bearing: zsh-syntax-highlighting wraps every zle widget
# that exists at the moment it is sourced, so it MUST come last — after fzf's
# widgets in 70-tools.zsh and after autosuggestions. Hence the 90- prefix.

# --- autosuggestions ---------------------------------------------------
# Ghost-text completion from history; accept with the right arrow / End.
if [[ -r /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh

    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#6c7086'   # Catppuccin overlay0
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)

    # Don't try to suggest against a huge pasted blob.
    ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

    # ctrl-space accepts the whole suggestion without moving the cursor.
    bindkey '^ ' autosuggest-accept
fi

# --- syntax highlighting -----------------------------------------------
# Colours the command line as you type: valid commands green, unknown red.
# A fast sanity check that you have not typo'd something destructive.
if [[ -r /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

    ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)
    _appearance_apply_zsh_highlighting "${TERM_APPEARANCE:-dark}"
fi
