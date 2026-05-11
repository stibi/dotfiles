#!/bin/bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <secret_name>"
  exit 1
fi

SECRET_NAME="$1"
OLD_PATH="secret/bastion/certificates"
NEW_PATH="secret/tls-certificates"

# Use "vault kv metadata get" to check if the secret exists at the new location.
if vault kv metadata get "${NEW_PATH}/${SECRET_NAME}" >/dev/null 2>&1; then
  echo "Secret '${SECRET_NAME}' already exists at '${NEW_PATH}/${SECRET_NAME}'. Exiting."
  exit 0
fi

# Retrieve the secret from the old location in JSON format.
secret_json=$(vault kv get -format=json "${OLD_PATH}/${SECRET_NAME}" 2>/dev/null) || {
  echo "Secret '${SECRET_NAME}' not found at '${OLD_PATH}/${SECRET_NAME}'. Exiting."
  exit 1
}

DATA=$(echo "$secret_json" | jq -r '.data.data')
if [ "$DATA" == "null" ]; then
  echo "No data found for secret '${SECRET_NAME}'. Exiting."
  exit 1
fi

TMPFILE=$(mktemp)
echo "$DATA" > "$TMPFILE"
vault kv put "${NEW_PATH}/${SECRET_NAME}" @"$TMPFILE"
rm "$TMPFILE"

echo "Secret '${SECRET_NAME}' successfully copied from '${OLD_PATH}' to '${NEW_PATH}'."

