# Interactive environment. PATH and asdf setup live in ~/.zshenv so they are
# also available to non-interactive SSH commands such as Herdr's remote server
# launcher.

export EDITOR=nvim
export VISUAL=nvim
export PAGER=less
export LESS='-R -F -X'

# starship reads this instead of guessing at $XDG_CONFIG_HOME.
export STARSHIP_CONFIG="$HOME/.config/starship.toml"

# bat's theme is NOT pinned here. Its default is `--theme=auto`, which queries
# the terminal itself; setting BAT_THEME would override that and leave it dark
# on a light terminal. 15-appearance.zsh sets BAT_THEME_DARK/BAT_THEME_LIGHT
# instead, which is what auto chooses between.
