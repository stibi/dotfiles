# PATH and environment.
#
# Mirrors what ~/.bashrc used to set up, so switching login shells does not
# silently lose a tool. typeset -U keeps the array duplicate-free, which
# matters because tmux/ssh can re-source this in nested shells.

typeset -U path PATH

path=(
    "$HOME/.local/bin"
    "$HOME/bin"
    $path
    /opt/nvim-linux-x86_64/bin
    /opt/hunkdiff-linux-x64/bin
)

# asdf version manager — shims must come before the system interpreters.
export ASDF_DATA_DIR="${ASDF_DATA_DIR:-$HOME/.asdf}"
if [[ -d $ASDF_DATA_DIR ]]; then
    path=("$ASDF_DATA_DIR/shims" "$HOME/.asdf/bin" $path)
fi

# Drop entries that do not exist on this box (N-/ = keep only real dirs).
path=($^path(N-/))

export EDITOR=nvim
export VISUAL=nvim
export PAGER=less
export LESS='-R -F -X'

# starship reads this instead of guessing at $XDG_CONFIG_HOME.
export STARSHIP_CONFIG="$HOME/.config/starship.toml"

# bat is installed as `batcat` on Debian; point its config at the same theme
# the rest of the setup uses.
export BAT_THEME="Catppuccin Mocha"
