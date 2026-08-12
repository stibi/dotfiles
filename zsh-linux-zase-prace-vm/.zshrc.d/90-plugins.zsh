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

    typeset -gA ZSH_HIGHLIGHT_STYLES
    ZSH_HIGHLIGHT_STYLES[command]='fg=#a6e3a1'          # green
    ZSH_HIGHLIGHT_STYLES[builtin]='fg=#a6e3a1'
    ZSH_HIGHLIGHT_STYLES[function]='fg=#a6e3a1'
    ZSH_HIGHLIGHT_STYLES[alias]='fg=#94e2d5'            # teal
    ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#f38ba8'    # red
    ZSH_HIGHLIGHT_STYLES[path]='fg=#89b4fa,underline'   # blue
    ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#f9e2af'   # yellow
    ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#f9e2af'
    ZSH_HIGHLIGHT_STYLES[comment]='fg=#6c7086'          # overlay0
fi
