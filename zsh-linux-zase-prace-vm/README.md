# zsh-linux-zase-prace-vm

Shell environment for the **zase-prace** Debian 13 work VM.

Unlike the `zsh/` package (macOS workstation), this one is deliberately
**not portable** — it assumes Debian paths, Debian package names and this
one machine. Keeping it separate means the macOS config never has to grow
`if darwin` branches.

## Contents

```
.zshrc                     loader — sources .zshrc.d/*.zsh in order
.zshrc.d/
  00-env.zsh               PATH, EDITOR, asdf, starship config location
  10-options.zsh           setopt / shell behaviour
  20-history.zsh           history file + dedup options
  30-completion.zsh        compinit (cached daily) + zstyles
  40-keybindings.zsh       emacs mode, history search, ctrl-x ctrl-e
  50-aliases.zsh           eza/bat/fd, apt, systemd, k8s
  55-kubernetes.zsh        merged KUBECONFIG from ~/.kube/configs, kubie aliases
  60-functions.zsh         certexp, gcd, mkcd, extract
  70-tools.zsh             fzf, zoxide, direnv, kubectl, starship init
  90-plugins.zsh           autosuggestions + syntax highlighting (must be last)
.config/starship.toml      prompt — always shows stibi@zase-prace in mauve
.kube/kubie.yaml           kubie — reads ~/.kube/configs/*.yaml, prompt disabled
```

The `90-` prefix is load-bearing: `zsh-syntax-highlighting` wraps every zle
widget that exists when it is sourced, so it has to come after fzf's widgets.

## Deploy

```sh
cd ~/dev/moje/dotfiles
stow -v --no-folding -t "$HOME" zsh-linux-zase-prace-vm
```

`--no-folding` matters. Without it stow replaces a directory with a single
symlink into this repo whenever every file under it comes from the package —
so `~/.kube` would become a link, and cluster credentials later written to
`~/.kube/configs/` would land inside the dotfiles repo. With it, real
directories are created and only leaf files are symlinked, which also lets
untracked local fragments sit in `~/.zshrc.d/`.

This is normally done for you by the `shell` role in the
[homelab](https://github.com/stibi/homelab) Ansible repo, which also installs
the packages the config expects.

> **Do not** stow the `starship` or `kubie` packages on this host as well.
> This package already provides `~/.config/starship.toml` and
> `~/.kube/kubie.yaml`, and stow will refuse with a conflict.
>
> The kubie config here differs from the shared `kubie/` package in one way:
> `prompt.disable` is `true`, because this host's starship config renders the
> kubernetes context itself. Leaving both enabled shows it twice.

## Machine-local secrets

`.zshrc` sources `~/.config/secrets.zsh` if it exists. That file lives outside
this repo on purpose — put API tokens and work-specific exports there.
