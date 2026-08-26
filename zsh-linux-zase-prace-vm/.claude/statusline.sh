#!/usr/bin/env bash
# Claude Code status line.
#
# Wired up via ~/.claude/settings.json:
#   "statusLine": { "type": "command", "command": "~/.claude/statusline.sh" }
#
# Claude Code pipes session JSON on stdin and prints whatever this writes.
# It runs on session start, each assistant message, /compact, and permission
# or vim mode changes — debounced at 300ms, not per keystroke — so a few
# milliseconds of work here is fine, but nothing slow or networked.
#
# Every segment answers "would seeing this change what I do?". Token counts,
# session duration and cost are deliberately absent: they are telemetry, and on
# a permanent row they train you to stop reading the row.

set -uo pipefail

json=$(cat)

# --- Catppuccin Mocha, matching the starship prompt ---------------------
r=$'\033[0m'; b=$'\033[1m'
mauve=$'\033[38;2;203;166;247m'
red=$'\033[38;2;243;139;168m'
peach=$'\033[38;2;250;179;135m'
yellow=$'\033[38;2;249;226;175m'
green=$'\033[38;2;166;227;161m'
sky=$'\033[38;2;137;220;235m'
blue=$'\033[38;2;137;180;250m'
overlay=$'\033[38;2;108;112;134m'

sep="${overlay}·${r}"
out=()

# --- host ---------------------------------------------------------------
# Same reasoning as the mauve badge in the starship prompt: in fullscreen TUI
# the shell prompt is off screen, so the "which machine" cue disappears exactly
# when an agent is able to change things.
out+=("${mauve}${b}$(whoami)@$(hostname -s)${r}")

# --- kubernetes context -------------------------------------------------
# Read from KUBECONFIG rather than shelling out to kubectl, which would cost
# ~100ms per render. This script inherits Claude Code's environment, which is
# the same environment its Bash tool runs kubectl in — so this is the cluster
# Claude would actually act against, not merely the one this terminal prefers.
kube_ctx=""
IFS=':' read -r -a _kube_files <<<"${KUBECONFIG:-$HOME/.kube/config}"
for _kf in "${_kube_files[@]}"; do
    [[ -r $_kf ]] || continue
    kube_ctx=$(sed -n 's/^current-context:[[:space:]]*//p' "$_kf" | head -1 | tr -d '"'\''')
    [[ -n $kube_ctx ]] && break
done

if [[ -n $kube_ctx ]]; then
    # Anything with prod as a whole segment is shown in red. Getting the wrong
    # cluster is the expensive mistake this row exists to prevent.
    if [[ $kube_ctx =~ (^|[-_.])(prod|production)([-_.]|$) ]]; then
        out+=("${red}${b}⎈ ${kube_ctx}${r}")
    else
        out+=("${sky}⎈ ${kube_ctx}${r}")
    fi
fi

# --- repo / branch ------------------------------------------------------
# One jq invocation for every field. Separate calls cost ~40ms of pure process
# spawn each, which dominates this script's runtime.
#
# Read line-by-line rather than @tsv into `read -d $'\t'`: tab counts as IFS
# whitespace, so `read` silently collapses runs of tabs and an empty field
# (git_worktree, usually) shifts every later value into the wrong variable.
mapfile -t _f < <(
    jq -r '
        (.workspace.current_dir // .cwd // ""),
        (.workspace.repo.name // ""),
        (.workspace.git_worktree // ""),
        (.model.display_name // ""),
        (.context_window.used_percentage // 0 | floor | tostring)
    ' <<<"$json"
)
cwd=${_f[0]-}; repo=${_f[1]-}; worktree=${_f[2]-}; model=${_f[3]-}; pct=${_f[4]:-0}

[[ -n $cwd ]] && cd "$cwd" 2>/dev/null

[[ -z $repo && -n $cwd ]] && repo=$(basename "$cwd")
[[ -n $repo ]] && out+=("${blue}${repo}${r}")

if branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) ||
   branch=$(git rev-parse --short HEAD 2>/dev/null); then
    # --quiet exits non-zero on any staged or unstaged change. Cheaper than
    # `git status --porcelain`, which walks untracked files too.
    dirty=""
    git diff --quiet --ignore-submodules HEAD 2>/dev/null || dirty="${peach}✱${r}"
    # A worktree is easy to forget you are in, and it changes what a commit means.
    [[ -n $worktree ]] && branch="${branch}${overlay}@${worktree}${r}${green}"
    out+=("${green}${branch}${r}${dirty}")
fi

# --- model --------------------------------------------------------------
[[ -n $model ]] && out+=("${overlay}${model}${r}")

# --- context window -----------------------------------------------------
# used_percentage is pre-calculated by Claude Code, so no arithmetic on tokens.
if [[ ${pct:-0} -gt 0 ]]; then
    if   (( pct >= 80 )); then pc=$red
    elif (( pct >= 60 )); then pc=$yellow
    else                       pc=$green
    fi
    filled=$(( pct * 8 / 100 ))
    bar=""
    for ((i = 0; i < 8; i++)); do
        (( i < filled )) && bar+="█" || bar+="░"
    done
    out+=("${pc}${bar} ${pct}%${r}")
fi

# --- render -------------------------------------------------------------
printf '%s' "${out[0]}"
for ((i = 1; i < ${#out[@]}; i++)); do
    printf ' %s %s' "$sep" "${out[i]}"
done
printf '\n'
