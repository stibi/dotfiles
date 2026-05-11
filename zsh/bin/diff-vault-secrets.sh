#!/bin/bash
set -euo pipefail

OLD_PATH="secret/bastion/certificates"
NEW_PATH="secret/tls-certificates"

# List all secrets in the old location (KV engine v2)
secrets_json=$(vault kv list -format=json "${OLD_PATH}" 2>/dev/null) || {
  echo "Failed to list secrets in ${OLD_PATH}"
  exit 1
}

# Parse the JSON array of keys.
secret_keys=$(echo "$secrets_json" | jq -r '.[]')

for key in $secret_keys; do
  # Skip directories (keys ending with '/')
  if [[ "$key" == */ ]]; then
    continue
  fi

  echo "Processing secret: ${key}"

  # Fetch the secret from the old location.
  old_secret_json=$(vault kv get -format=json "${OLD_PATH}/${key}" 2>/dev/null) || {
    echo "  [ERROR] Failed to fetch secret from ${OLD_PATH}/${key}"
    continue
  }

  # Check if the secret exists in the new location.
  if ! vault kv metadata get "${NEW_PATH}/${key}" >/dev/null 2>&1; then
    echo "  [MISSING] Secret ${key} exists in ${OLD_PATH} but is missing in ${NEW_PATH}"
    continue
  fi

  # Fetch the secret from the new location.
  new_secret_json=$(vault kv get -format=json "${NEW_PATH}/${key}" 2>/dev/null) || {
    echo "  [ERROR] Failed to fetch secret from ${NEW_PATH}/${key}"
    continue
  }

  # Extract and canonicalize the secret data (assumes KV v2 where secret data is under .data.data)
  old_data=$(echo "$old_secret_json" | jq -S '.data.data')
  new_data=$(echo "$new_secret_json" | jq -S '.data.data')

  # Compute hashes for a simple diff.
  old_hash=$(echo "$old_data" | sha256sum | awk '{print $1}')
  new_hash=$(echo "$new_data" | sha256sum | awk '{print $1}')

  if [ "$old_hash" = "$new_hash" ]; then
    echo "  [MATCH] Secret ${key} matches between ${OLD_PATH} and ${NEW_PATH}"
  else
    echo "  [DIFF] Secret ${key} differs between ${OLD_PATH} and ${NEW_PATH}"
  fi
done
