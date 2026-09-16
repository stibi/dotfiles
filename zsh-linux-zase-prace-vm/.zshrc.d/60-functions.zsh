# Shell functions.

# certexp <domain> — show issuer/validity of a TLS cert with a colour-coded
# warning as expiry approaches. Linux port of the macOS version (plain
# `date -d` here instead of gdate).
certexp() {
    if [[ -z "$1" ]]; then
        echo "Usage: certexp <domain>"
        return 1
    fi

    local critical_threshold=10   # days_left <= 10: red
    local warning_threshold=20    # days_left <= 20: orange

    local domain="$1" cert_info
    cert_info=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null \
                | openssl x509 -noout -dates -issuer 2>/dev/null)

    local issued expiration issuer
    issued=$(echo "$cert_info"     | grep 'notBefore=' | cut -d'=' -f2-)
    expiration=$(echo "$cert_info" | grep 'notAfter='  | cut -d'=' -f2-)
    issuer=$(echo "$cert_info"     | grep 'issuer='    | cut -d'=' -f2-)

    if [[ -z "$issued" || -z "$expiration" || -z "$issuer" ]]; then
        echo "Could not retrieve certificate details for $domain"
        return 1
    fi

    local exp_ts
    exp_ts=$(date -d "$expiration" +%s 2>/dev/null)
    if [[ -z "$exp_ts" ]]; then
        echo "Error parsing expiration date."
        return 1
    fi

    local days_left=$(( (exp_ts - $(date +%s)) / 86400 ))
    local reset="\033[0m" red="\033[31m" orange="\033[38;5;208m" green="\033[32m"
    local output="Issuer: $issuer\nIssued: $issued\nExpires: $expiration\nDays left: $days_left"

    if (( days_left < 0 )); then
        echo -e "${red}${output} ❗${reset}\n! The cert is already expired !"
    elif (( days_left <= critical_threshold )); then
        echo -e "${red}${output} ❗${reset}"
    elif (( days_left <= warning_threshold )); then
        echo -e "${orange}${output} ⚠️${reset}"
    else
        echo -e "${green}${output} ✅${reset}"
    fi
}

# omnictl [arguments...]
#
# Load the Omni API service account only for this invocation. The subshell keeps
# the credential out of the interactive shell environment after omnictl exits.
omnictl() (
    local env_file="$HOME/.config/omni/env"

    [[ -r "$env_file" ]] || {
        printf 'omnictl: cannot read %s\n' "$env_file" >&2
        return 1
    }

    set -a
    source "$env_file" || return 1
    set +a

    [[ -n "${OMNI_ENDPOINT:-}" && -n "${OMNI_SERVICE_ACCOUNT_KEY:-}" ]] || {
        printf '%s\n' 'omnictl: Omni service-account environment is incomplete' >&2
        return 1
    }

    command omnictl "$@"
)

# talosctl-omni <cluster> [talosctl arguments...]
#
# Selects the matching Omni service account and generated talosconfig. The
# subshell is deliberate: the exported service-account secret disappears as
# soon as talosctl exits instead of leaking into the interactive environment.
# Cluster names map to these credential pairs:
#
#   ~/.config/omni/<cluster>-talos-client.env
#   ~/.talos/configs/<cluster>-talos-client.yaml
talosctl-omni-clusters() {
    local config_file cluster env_file found=0

    while IFS= read -r config_file; do
        cluster="${config_file##*/}"
        cluster="${cluster%-talos-client.yaml}"
        env_file="$HOME/.config/omni/${cluster}-talos-client.env"

        # A config without its matching service-account environment is not
        # usable through talosctl-omni, so do not advertise partial pairs.
        if [[ -r "$env_file" ]]; then
            printf '%s\n' "$cluster"
            found=1
        fi
    done < <(
        find "$HOME/.talos/configs" -maxdepth 1 -type f \
            -name '*-talos-client.yaml' -readable -print 2>/dev/null | sort
    )

    if (( ! found )); then
        printf '%s\n' 'talosctl-omni-clusters: no complete credential pairs found' >&2
        return 1
    fi
}

talosctl-omni() (
    local cluster="${1:-}"

    if [[ -z "$cluster" ]]; then
        printf '%s\n' \
            'Usage: talosctl-omni <cluster> [talosctl arguments...]' \
            '       talosctl-omni --list' \
            'Example: talosctl-omni dat --nodes <machine-uuid> version' \
            '' 'Available clusters:' >&2
        talosctl-omni-clusters >&2
        return 1
    fi
    if [[ "$cluster" == "--list" ]]; then
        talosctl-omni-clusters
        return
    fi
    if [[ "$cluster" == "-h" || "$cluster" == "--help" ]]; then
        printf '%s\n' \
            'Usage: talosctl-omni <cluster> [talosctl arguments...]' \
            '       talosctl-omni --list' \
            'Example: talosctl-omni dat --nodes <machine-uuid> version'
        return 0
    fi
    shift

    # Keep the value safe to interpolate into paths. Omni cluster names in
    # use here are lowercase DNS labels (for example dat and crm-prod).
    case "$cluster" in
        *[!a-z0-9-]*|-*|*-)
            printf 'talosctl-omni: invalid cluster name: %s\n' "$cluster" >&2
            return 2
            ;;
    esac

    local env_file="$HOME/.config/omni/${cluster}-talos-client.env"
    local config_file="$HOME/.talos/configs/${cluster}-talos-client.yaml"

    [[ -r "$env_file" ]] || {
        printf 'talosctl-omni: cannot read %s\n' "$env_file" >&2
        return 1
    }
    [[ -r "$config_file" ]] || {
        printf 'talosctl-omni: cannot read %s\n' "$config_file" >&2
        return 1
    }

    set -a
    source "$env_file" || return 1
    set +a

    [[ -n "${OMNI_ENDPOINT:-}" && -n "${OMNI_SERVICE_ACCOUNT_KEY:-}" ]] || {
        printf '%s\n' 'talosctl-omni: Omni service-account environment is incomplete' >&2
        return 1
    }

    command talosctl --talosconfig "$config_file" "$@"
)

# gcd — fzf-pick a file changed in the current repo and cd to its directory.
gcd() {
    local git_status count file dir
    git_status=$(git status --porcelain) || return
    [[ -z "$git_status" ]] && { echo "No changes."; return; }

    count=$(echo "$git_status" | wc -l | tr -d ' ')
    (( count > 20 )) && count=20
    count=$(( count + 2 ))   # room for the prompt line and border

    file=$(echo "$git_status" \
        | sed -E 's/^[[:space:]]*..[[:space:]]*//' \
        | fzf --height="${count}" --prompt="Select changed file: ")
    [[ -z "$file" ]] && return

    dir=$(dirname "$file")
    cd "$(git rev-parse --show-toplevel)/$dir" || return
}

# mkcd <dir> — make a directory and step into it.
mkcd() {
    [[ -z "$1" ]] && { echo "Usage: mkcd <dir>"; return 1; }
    mkdir -p "$1" && cd "$1"
}

# extract <archive> — unpack whatever it happens to be.
extract() {
    [[ -f "$1" ]] || { echo "extract: '$1' is not a file"; return 1; }
    case "$1" in
        *.tar.bz2|*.tbz2) tar xjf "$1"   ;;
        *.tar.gz|*.tgz)   tar xzf "$1"   ;;
        *.tar.xz)         tar xJf "$1"   ;;
        *.tar.zst)        tar --zstd -xf "$1" ;;
        *.tar)            tar xf "$1"    ;;
        *.bz2)            bunzip2 "$1"   ;;
        *.gz)             gunzip "$1"    ;;
        *.zip)            unzip "$1"     ;;
        *.7z)             7z x "$1"      ;;
        *)                echo "extract: don't know how to handle '$1'"; return 1 ;;
    esac
}
