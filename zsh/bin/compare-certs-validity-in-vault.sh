#!/bin/bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <secret name>"
    exit 1
fi

SECRET_NAME="$1"

# Configure the Vault path prefixes
PATH_PREFIX1="secret/bastion/certificates"    # adjust as needed
PATH_PREFIX2="secret/tls-certificates"   # adjust as needed

SECRET_PATH1="${PATH_PREFIX1}/${SECRET_NAME}"
SECRET_PATH2="${PATH_PREFIX2}/${SECRET_NAME}"

if [ -z "${VAULT_TOKEN:-}" ]; then
    echo "Error: VAULT_TOKEN environment variable not set"
    exit 1
fi

if [ -z "${VAULT_ADDR:-}" ]; then
    VAULT_ADDR="http://127.0.0.1:8200"
fi

# Fetch secrets from Vault (KV v2 assumed)
secret_json1=$(vault kv get -format=json "$SECRET_PATH1") || {
    echo "Error reading secret from Vault at $SECRET_PATH1"
    exit 1
}
secret_json2=$(vault kv get -format=json "$SECRET_PATH2") || {
    echo "Error reading secret from Vault at $SECRET_PATH2"
    exit 1
}

fullchain_pem1=$(echo "$secret_json1" | jq -r '.data.data["fullchain.pem"]')
privkey_pem1=$(echo "$secret_json1" | jq -r '.data.data["privkey.pem"]')
fullchain_pem2=$(echo "$secret_json2" | jq -r '.data.data["fullchain.pem"]')
privkey_pem2=$(echo "$secret_json2" | jq -r '.data.data["privkey.pem"]')

if [ -z "$fullchain_pem1" ] || [ -z "$privkey_pem1" ]; then
    echo "Error: Secret at $SECRET_PATH1 must contain both 'fullchain.pem' and 'privkey.pem'"
    exit 1
fi

if [ -z "$fullchain_pem2" ] || [ -z "$privkey_pem2" ]; then
    echo "Error: Secret at $SECRET_PATH2 must contain both 'fullchain.pem' and 'privkey.pem'"
    exit 1
fi

# Write first certificate to temp file (using only the first certificate block)
tmp_cert1=$(mktemp)
tmp_cert2=$(mktemp)
echo "$fullchain_pem1" | awk '/BEGIN CERTIFICATE/ {flag=1} flag {print} /END CERTIFICATE/ {flag=0; exit}' > "$tmp_cert1"
echo "$fullchain_pem2" | awk '/BEGIN CERTIFICATE/ {flag=1} flag {print} /END CERTIFICATE/ {flag=0; exit}' > "$tmp_cert2"

# Extract the expiration dates from the certificates
end_date1=$(openssl x509 -in "$tmp_cert1" -noout -enddate 2>/dev/null | cut -d= -f2)
end_date2=$(openssl x509 -in "$tmp_cert2" -noout -enddate 2>/dev/null | cut -d= -f2)

if [ -z "$end_date1" ]; then
    echo "Error: Unable to extract certificate expiry date from $SECRET_PATH1."
    rm -f "$tmp_cert1" "$tmp_cert2"
    exit 1
fi

if [ -z "$end_date2" ]; then
    echo "Error: Unable to extract certificate expiry date from $SECRET_PATH2."
    rm -f "$tmp_cert1" "$tmp_cert2"
    exit 1
fi

# Convert expiry dates to epoch seconds for comparison
end_epoch1=$(gdate -d "$end_date1" +%s)
end_epoch2=$(gdate -d "$end_date2" +%s)

if [ "$end_epoch1" -gt "$end_epoch2" ]; then
    echo "The newer certificate is stored at: $SECRET_PATH1"
elif [ "$end_epoch2" -gt "$end_epoch1" ]; then
    echo "The newer certificate is stored at: $SECRET_PATH2"
else
    echo "Both certificates have the same expiry date: $end_date1"
fi

rm -f "$tmp_cert1" "$tmp_cert2"
