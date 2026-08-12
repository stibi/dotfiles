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

# gcd — fzf-pick a file changed in the current repo and cd to its directory.
gcd() {
    local git_status count file dir
    git_status=$(git status --porcelain) || return
    [[ -z "$git_status" ]] && { echo "No changes."; return }

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
    [[ -z "$1" ]] && { echo "Usage: mkcd <dir>"; return 1 }
    mkdir -p "$1" && cd "$1"
}

# extract <archive> — unpack whatever it happens to be.
extract() {
    [[ -f "$1" ]] || { echo "extract: '$1' is not a file"; return 1 }
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
