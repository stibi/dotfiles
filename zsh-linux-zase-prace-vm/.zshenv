# PATH needed by every zsh, including non-interactive SSH commands. Herdr's
# remote launcher starts its server that way, so plugin runtimes managed by
# asdf (such as Node.js) must be visible before .zshrc is involved.

typeset -U path PATH

path=(
    "${KREW_ROOT:-$HOME/.krew}/bin"
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
