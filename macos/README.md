# macOS appearance watcher

Automatically syncs app config files to the current macOS appearance (Light/Dark).
Runs as a per-user `launchd` agent — set-and-forget after install.

## What gets synced

| App        | File                          | What changes                                  |
|------------|-------------------------------|-----------------------------------------------|
| k9s        | `~/.config/k9s/config.yaml`   | `skin: catppuccin-latte` ↔ `catppuccin-mocha` |
| kubecolor  | `~/.kube/color.yaml`          | `preset: light` ↔ `preset: dark`              |
| tmux       | `~/.tmux.conf`                | Re-sourced; its own `if-shell` picks variant  |
| Ghostty    | (handled natively, no script) | `theme = light:...,dark:...` directive        |

The Ghostty terminal switches itself via its native dual-theme syntax — the script
is not involved.

## How it works

```
.GlobalPreferences.plist changes ──► launchd WatchPaths trigger ──┐
                                                                  ├─► apply-appearance.sh
launchd StartInterval (every 10s) ────────────────────────────────┘     │
                                                                        ▼
                                                          detect current mode
                                                          (defaults read -g AppleInterfaceStyle)
                                                                        │
                                                       if mode changed since last run
                                                                        │
                                                     ┌──────────────────┼──────────────────┐
                                                     ▼                  ▼                  ▼
                                                  sed k9s          sed kubecolor    tmux source-file
```

Two trigger sources for robustness:

- **WatchPaths** on `~/Library/Preferences/.GlobalPreferences.plist` — fires
  near-instantly when macOS writes appearance changes.
- **StartInterval=10** — polls every 10 seconds as a fallback in case
  `cfprefsd` doesn't flush the watched plist on every change.

The script is idempotent: it stores the last applied mode in
`~/.cache/appearance-watcher.last` and exits immediately if the current mode
matches. Both triggers can fire many times — only an actual change does work
and adds a log entry.

## Files

- `apply-appearance.sh` — the sync script
- `cz.stibi.appearance.plist` — the launchd agent definition
- `README.md` — this file

The plist is symlinked into `~/Library/LaunchAgents/` so dotfile edits flow
through. Re-load is only needed when the **plist itself** is edited; edits to
the shell script take effect on the next trigger.

## Install (one-time)

```sh
ln -sfn ~/dev/moje/dotfiles/macos/cz.stibi.appearance.plist \
        ~/Library/LaunchAgents/cz.stibi.appearance.plist
launchctl load ~/Library/LaunchAgents/cz.stibi.appearance.plist
```

## Manage

```sh
# Is it loaded?
launchctl list | grep cz.stibi.appearance
# Output is "PID  exit  label". PID = "-" means it's loaded but not currently
# running (expected — the script is short-lived). exit "0" = last run OK.

# Detailed state
launchctl print "gui/$UID/cz.stibi.appearance"

# View log (always-on append)
tail -f /tmp/appearance-watcher.log

# Stop (unload)
launchctl unload ~/Library/LaunchAgents/cz.stibi.appearance.plist

# Start (load)
launchctl load ~/Library/LaunchAgents/cz.stibi.appearance.plist

# Restart (after editing the plist itself)
launchctl unload ~/Library/LaunchAgents/cz.stibi.appearance.plist && \
launchctl load   ~/Library/LaunchAgents/cz.stibi.appearance.plist

# Force-run the script manually (e.g., after editing it)
~/dev/moje/dotfiles/macos/apply-appearance.sh

# Force-run ignoring the cached "no change" guard
rm -f ~/.cache/appearance-watcher.last && \
~/dev/moje/dotfiles/macos/apply-appearance.sh
```

## Adding another app

Edit `apply-appearance.sh`. The pattern is: detect the current `$mode`
(`light`/`dark`), then `sed` the relevant file. Example skeleton:

```sh
some_config="$HOME/.config/foo/config"
if [[ -f "$some_config" ]]; then
    if [[ "$mode" == dark ]]; then
        sed -i '' -E 's/^theme:[[:space:]]+light$/theme: dark/' "$some_config"
    else
        sed -i '' -E 's/^theme:[[:space:]]+dark$/theme: light/' "$some_config"
    fi
fi
```

If the app needs to be signalled to reload, add it at the bottom (see the tmux
block for an example).

No need to reload launchd — script edits take effect on the next trigger.

## Troubleshooting

**Nothing in the log after a toggle.**
The script only logs when mode actually changed. Check the cached value:
```sh
cat ~/.cache/appearance-watcher.last        # last-applied mode
defaults read -g AppleInterfaceStyle 2>&1    # "Dark" or error (= Light)
```
If they match, the script correctly did nothing. If they differ, the agent
isn't being triggered — check `launchctl list | grep appearance` and the log
file for errors.

**Agent shows last exit code != 0.**
Run the script by hand to see the error: `~/dev/moje/dotfiles/macos/apply-appearance.sh`

**Agent missing from `launchctl list`.**
The symlink or `launchctl load` step was skipped — see Install above.

**k9s shows the wrong skin.**
A *running* k9s session caches its skin at startup. Quit and relaunch k9s;
new sessions pick up the synced file.
