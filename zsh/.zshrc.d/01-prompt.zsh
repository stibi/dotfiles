# Because of pure zsh theme
fpath+=("$HOME/dev/pure")

# Initialize pure zsh theme
autoload -U promptinit; promptinit
prompt pure
