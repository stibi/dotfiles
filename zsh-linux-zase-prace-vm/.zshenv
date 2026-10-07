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

# Vault Agent on this VM proxies 127.0.0.1:8200 and injects its own AppRole
# token, so clients send none (interactive OIDC login is not possible here).
export VAULT_ADDR=http://127.0.0.1:8200
export ANSIBLE_HASHI_VAULT_AUTH_METHOD=none
# Placeholder only: the agent replaces it, but some clients (the Terraform
# Vault provider) refuse to start without a token.
export VAULT_TOKEN=vault-agent-placeholder
export ANSIBLE_PRIVATE_KEY_FILE="$HOME/.ssh/atlas-ansible"
