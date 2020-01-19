# Because of pure zsh theme
fpath+=("$HOME/dev/projects/pure")

# Initialize pure zsh theme
autoload -U promptinit; promptinit
prompt pure
