function certexp() {
  if [[ -z "$1" ]]; then
    echo "Usage: cert_expiration domain"
    return 1
  fi

  # Configurable thresholds (in days)
  local expired_threshold=0       # days_left < 0 means already expired
  local critical_threshold=10     # days_left <= 10: critical warning (red)
  local warning_threshold=20      # days_left <= 20: warning (orange)

  local domain="$1"
  local cert_info
  cert_info=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null \
              | openssl x509 -noout -dates -issuer 2>/dev/null)

  local issued=$(echo "$cert_info" | grep 'notBefore=' | cut -d'=' -f2-)
  local expiration=$(echo "$cert_info" | grep 'notAfter=' | cut -d'=' -f2-)
  local issuer=$(echo "$cert_info" | grep 'issuer=' | cut -d'=' -f2-)

  if [[ -z "$issued" || -z "$expiration" || -z "$issuer" ]]; then
    echo "Could not retrieve certificate details for $domain"
    return 1
  fi

  # Convert expiration date to epoch seconds (requires GNU date)
  local exp_ts
  exp_ts=$(gdate -d "$expiration" +%s 2>/dev/null)
  if [[ -z "$exp_ts" ]]; then
    echo "Error parsing expiration date."
    return 1
  fi

  local now_ts=$(date +%s)
  local days_left=$(( (exp_ts - now_ts) / 86400 ))

  # ANSI color codes
  local reset="\033[0m"
  local red="\033[31m"
  local orange="\033[38;5;208m"
  local green="\033[32m"

  local output="Issuer: $issuer\nIssued: $issued\nExpires: $expiration\nDays left: $days_left"

  if (( days_left < expired_threshold )); then
    echo -e "${red}${output} ❗${reset}\n! The cert is already expired !"
  elif (( days_left <= critical_threshold )); then
    echo -e "${red}${output} ❗${reset}"
  elif (( days_left <= warning_threshold )); then
    echo -e "${orange}${output} ⚠️${reset}"
  else
    echo -e "${green}${output} ✅${reset}"
  fi
}

cleanMacosTurd() {
  find . -type f -name '._*' -size -4096 -print -delete
}

#gcd() {
  #file=$(git status --porcelain | sed 's/^..//' | fzf --prompt="Select changed file: ")
#  file=$(git status --porcelain | sed -E 's/^[[:space:]]*..[[:space:]]*//' | fzf --prompt="Select changed file: ")
#  echo "Vybrany soubor je: '${file}'"
#  dir=$(dirname "$file")
  #echo "Dir je '${dir}'"
  # Change directory using an absolute path built from the repository root
#  cd "$(git rev-parse --show-toplevel)/$dir" || return
  #toplevel_dla_gita="$(git rev-parse --show-toplevel)/$dir"
  #echo "Kam me chce vzit git: '${toplevel_dla_gita}'"
#}

gcd() {
  local git_status count file dir
  git_status=$(git status --porcelain)
  count=$(echo "$git_status" | wc -l | tr -d ' ')
  [ "$count" -gt 20 ] && count=20
  # o dva je to treba zvetsit, at se to vykresli spravne
  count=$((count+2))
  file=$(echo "$git_status" \
    | sed -E 's/^[[:space:]]*..[[:space:]]*//' \
    | fzf --height="${count}" --prompt="Select changed file: ")
  [ -z "$file" ] && return
  dir=$(dirname "$file")
  cd "$(git rev-parse --show-toplevel)/$dir" || return
}

