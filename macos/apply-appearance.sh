#!/usr/bin/env bash
# Sync app config files to the current macOS appearance (light/dark).
# Idempotent: only acts when the mode has actually changed since last run.

set -euo pipefail

if defaults read -g AppleInterfaceStyle 2>/dev/null | grep -q Dark; then
    mode=dark
else
    mode=light
fi

state_file="$HOME/.cache/appearance-watcher.last"
mkdir -p "$(dirname "$state_file")"
last_mode=$(cat "$state_file" 2>/dev/null || echo "")

if [[ "$mode" == "$last_mode" ]]; then
    exit 0
fi
echo "$mode" > "$state_file"

ts=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$ts] appearance=$mode (was: ${last_mode:-unknown})"

# --- k9s skin ---
# Handled by K9S_SKIN env var in zsh/.zshrc.d/appearance.zsh; nothing to do here.
# New shells will pick up the right skin; restart k9s itself to see it.

# --- kubecolor preset ---
kube_color="$HOME/.kube/color.yaml"
if [[ -f "$kube_color" ]]; then
    if [[ "$mode" == dark ]]; then
        sed -i '' -E "s/^preset:[[:space:]]+light[[:space:]]*$/preset: dark/" "$kube_color"
    else
        sed -i '' -E "s/^preset:[[:space:]]+dark[[:space:]]*$/preset: light/" "$kube_color"
    fi
fi

# --- tmux: re-source so the if-shell flavor check re-evaluates ---
if command -v tmux >/dev/null 2>&1 && tmux list-sessions >/dev/null 2>&1; then
    tmux source-file "$HOME/.tmux.conf" || true
fi
