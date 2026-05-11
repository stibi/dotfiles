#!/bin/bash
set -euo pipefail

# Define colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <vault secret path>"
    exit 1
fi

SECRET_PATH="$1"

if [ -z "${VAULT_TOKEN:-}" ]; then
    echo "Error: VAULT_TOKEN environment variable not set"
    exit 1
fi

if [ -z "${VAULT_ADDR:-}" ]; then
    VAULT_ADDR="http://127.0.0.1:8200"
fi

# Fetch secret from Vault (KV v2 expected)
secret_json=$(vault kv get -format=json "$SECRET_PATH") || {
    echo "Error reading secret from Vault"
    exit 1
}

fullchain_pem=$(echo "$secret_json" | jq -r '.data.data["fullchain.pem"]')
privkey_pem=$(echo "$secret_json" | jq -r '.data.data["privkey.pem"]')
# fullchain_pem=$(echo "$secret_json" | jq -r '.data.data["tls.crt"]')
# privkey_pem=$(echo "$secret_json" | jq -r '.data.data["tls.key"]')

if [ -z "$fullchain_pem" ] || [ -z "$privkey_pem" ]; then
    echo "Error: Secret must contain both 'fullchain.pem' and 'privkey.pem'"
    exit 1
fi

# Write certificate and key to temporary files
tmp_cert=$(mktemp)
tmp_key=$(mktemp)

# Extract the first certificate block from fullchain.pem
echo "$fullchain_pem" | awk '/BEGIN CERTIFICATE/ {flag=1} flag {print} /END CERTIFICATE/ {flag=0; exit}' > "$tmp_cert"
echo "$privkey_pem" > "$tmp_key"

# Get certificate validity dates
start_date=$(openssl x509 -in "$tmp_cert" -noout -startdate 2>/dev/null | cut -d= -f2)
end_date=$(openssl x509 -in "$tmp_cert" -noout -enddate 2>/dev/null | cut -d= -f2)

if [ -z "$start_date" ] || [ -z "$end_date" ]; then
    echo "Error: Unable to extract certificate validity dates."
    rm -f "$tmp_cert" "$tmp_key"
    exit 1
fi

# Convert dates to epoch seconds
start_epoch=$(gdate -d "$start_date" +%s)
end_epoch=$(gdate -d "$end_date" +%s)
now_epoch=$(gdate -u +%s)

if [ "$now_epoch" -lt "$start_epoch" ]; then
    echo -e "${RED}Certificate not yet valid. Valid from: $start_date${NC}"
elif [ "$now_epoch" -gt "$end_epoch" ]; then
    echo -e "${RED}Certificate expired on: $end_date${NC}"
else
    # Calculate days until expiration
    days_remaining=$(( (end_epoch - now_epoch) / 86400 ))
    echo -e "${GREEN}Certificate is currently valid until: $end_date ($days_remaining days remaining)${NC}"
fi

# Check if certificate and private key match
cert_pub=$(openssl x509 -in "$tmp_cert" -noout -pubkey 2>/dev/null | openssl pkey -pubin -outform pem 2>/dev/null)
key_pub=$(openssl pkey -in "$tmp_key" -pubout -outform pem 2>/dev/null)

if [ "$cert_pub" = "$key_pub" ]; then
    echo -e "${GREEN}Certificate and private key match.${NC}"
else
    echo -e "${RED}Certificate and private key do NOT match.${NC}"
fi

rm -f "$tmp_cert" "$tmp_key"
