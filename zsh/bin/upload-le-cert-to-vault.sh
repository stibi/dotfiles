#!/usr/bin/env bash

set -euo pipefail

# Configuration (can be overridden by environment variables)
VAULT="${VAULT_CMD:-$(which vault 2>/dev/null || true)}"
CERTS_SECRET_PATH="${VAULT_CERTS_PATH:-/secret/tls-certificates}"
CERT_FILE_EXTENSION=".cer"
KEY_FILE_EXTENSION=".key"
FULLCHAIN_FILE="fullchain.cer"
VAULT_CERT_KEY="fullchain.pem"
VAULT_KEY_KEY="privkey.pem"
DRY_RUN="${DRY_RUN:-false}"
VERBOSE="${VERBOSE:-false}"

# Color definitions
if [ -t 1 ]; then  # Only use colors if outputting to terminal
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  BG_BLUE='\033[44m'
  WHITE='\033[1;37m'
  NC='\033[0m'
else
  GREEN='' RED='' YELLOW='' BLUE='' BG_BLUE='' WHITE='' NC=''
fi

# Logging functions
log_error() { printf "${RED}❌ Error: $1${NC}\n" >&2; }
log_warn() { printf "${YELLOW}⚠️  Warning: $1${NC}\n"; }
log_info() { printf "${BLUE}ℹ️  $1${NC}\n"; }
log_success() { printf "${GREEN}✅ $1${NC}\n"; }
log_debug() {
  if [ "$VERBOSE" = "true" ]; then
    printf "${BLUE}🔍 Debug: $1${NC}\n"
  fi
  return 0
}

# Cleanup function
cleanup() {
  local exit_code=$?
  [ -n "${VAULT_CERT_TEMP:-}" ] && [ -f "$VAULT_CERT_TEMP" ] && rm -f "$VAULT_CERT_TEMP"
  exit $exit_code
}
trap cleanup EXIT INT TERM

# Check prerequisites
check_prerequisites() {
  if [ -z "$VAULT" ]; then
    log_error "vault command not found. Please install Vault CLI."
    exit 1
  fi

  if ! command -v openssl &>/dev/null; then
    log_error "openssl command not found. Please install OpenSSL."
    exit 1
  fi

  if ! command -v jq &>/dev/null; then
    log_error "jq command not found. Please install jq."
    exit 1
  fi

  # Check vault authentication
  if [ "${SKIP_VAULT_AUTH_CHECK:-}" != "true" ]; then
    if ! $VAULT token lookup &>/dev/null; then
      log_error "Not authenticated to Vault. Please run 'vault login' first."
      exit 1
    fi
  else
    log_warn "Skipping Vault authentication check (SKIP_VAULT_AUTH_CHECK=true)"
  fi
}

# Usage function
usage() {
  cat <<EOF
Usage: $0 [OPTIONS] /path/to/acme.sh/certificate/directory/

Upload Let's Encrypt certificates to HashiCorp Vault

Options:
  -d, --dry-run     Preview changes without uploading
  -v, --verbose     Enable verbose output
  -f, --force       Skip confirmation prompts
  -h, --help        Show this help message

Environment Variables:
  VAULT_CMD          Path to vault command (default: auto-detect)
  VAULT_CERTS_PATH   Base path for certificates in Vault (default: /secret/tls-certificates)
  DRY_RUN           Set to 'true' for dry-run mode
  VERBOSE           Set to 'true' for verbose output

Examples:
  $0 ~/.acme.sh/example.com_ecc/
  $0 --dry-run ~/.acme.sh/*.example.com_ecc/
  VAULT_CERTS_PATH=/secret/certs $0 ~/.acme.sh/example.com_ecc/
EOF
}

# Parse command line arguments
FORCE_MODE=false
while [[ $# -gt 0 ]]; do
  case $1 in
    -d|--dry-run)
      DRY_RUN=true
      shift
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -f|--force)
      FORCE_MODE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      log_error "Unknown option: $1"
      usage
      exit 1
      ;;
    *)
      if [ -n "${CERT_PATH:-}" ]; then
        log_error "Multiple certificate paths provided. Please specify only one path."
        log_error "First path: $CERT_PATH"
        log_error "Additional path: $1"
        log_info "Hint: If using wildcards, escape them (e.g., ~/.acme.sh/\\*.agrp.dev_ecc) or use quotes with full path"
        exit 1
      fi
      CERT_PATH="${1%/}"  # Remove trailing slash if present
      shift
      ;;
  esac
done

# Check if certificate path is provided
if [ -z "${CERT_PATH:-}" ]; then
  log_error "Certificate path not provided"
  usage
  exit 1
fi

# Run prerequisite checks
check_prerequisites

# Validate certificate path
if [ ! -d "$CERT_PATH" ]; then
  log_error "Certificate directory does not exist: $CERT_PATH"
  exit 1
fi

# Parse domain from path
RAW_DOMAIN_FROM_PATH=$(basename "$CERT_PATH")
DOMAIN=${RAW_DOMAIN_FROM_PATH%_ecc}

# Determine vault path based on wildcard status
if [[ "$DOMAIN" == \** ]]; then
  VAULT_PATH_SUFFIX_DOMAIN="any-${DOMAIN#\*.}"
  log_info "Detected wildcard certificate for domain: ${DOMAIN}"
else
  VAULT_PATH_SUFFIX_DOMAIN="${DOMAIN}"
fi
FULL_SECRET_PATH="${CERTS_SECRET_PATH}/${VAULT_PATH_SUFFIX_DOMAIN}"

# Validate required certificate files
FULLCHAIN_PATH="$CERT_PATH/$FULLCHAIN_FILE"
KEY_PATH="$CERT_PATH/${DOMAIN}${KEY_FILE_EXTENSION}"

if [ ! -f "$FULLCHAIN_PATH" ]; then
  log_error "Fullchain certificate file not found: $FULLCHAIN_PATH"
  exit 1
fi

if [ ! -f "$KEY_PATH" ]; then
  log_error "Private key file not found: $KEY_PATH"
  exit 1
fi

# Verify certificate and key match
verify_cert_key_match() {
  log_debug "Verifying certificate and key match..."
  log_debug "Certificate path: $FULLCHAIN_PATH"
  log_debug "Private key path: $KEY_PATH"

  # Check if files exist and are readable
  if [ ! -r "$FULLCHAIN_PATH" ]; then
    log_error "Certificate file not readable: $FULLCHAIN_PATH"
    return 1
  fi

  if [ ! -r "$KEY_PATH" ]; then
    log_error "Private key file not readable: $KEY_PATH"
    return 1
  fi

  # Detect if this is an ECC key based on directory name or key content
  local is_ecc=false
  if [[ "$CERT_PATH" == *_ecc* ]] || openssl ec -in "$KEY_PATH" -noout 2>/dev/null; then
    is_ecc=true
    log_debug "Detected ECC certificate/key pair"
  else
    log_debug "Detected RSA certificate/key pair"
  fi

  # For ECC keys, we need to compare public keys differently
  if [ "$is_ecc" = true ]; then
    # Extract public key from certificate
    local cert_pubkey=$(openssl x509 -noout -pubkey -in "$FULLCHAIN_PATH" 2>/dev/null | openssl md5)
    local cert_exit_code=${PIPESTATUS[0]}

    if [ $cert_exit_code -ne 0 ]; then
      log_error "Failed to extract public key from certificate: $FULLCHAIN_PATH"
      log_error "OpenSSL error: $(openssl x509 -noout -pubkey -in "$FULLCHAIN_PATH" 2>&1)"
      return 1
    fi

    # Extract public key from private key
    local key_pubkey=$(openssl ec -in "$KEY_PATH" -pubout 2>/dev/null | openssl md5)
    local key_exit_code=${PIPESTATUS[0]}

    if [ $key_exit_code -ne 0 ]; then
      log_error "Failed to extract public key from private key: $KEY_PATH"
      log_error "OpenSSL error: $(openssl ec -in "$KEY_PATH" -pubout 2>&1)"
      return 1
    fi

    log_debug "Certificate public key hash: $cert_pubkey"
    log_debug "Private key public key hash: $key_pubkey"

    if [ "$cert_pubkey" != "$key_pubkey" ]; then
      log_error "Certificate and private key do not match!"
      log_error "Certificate path: $FULLCHAIN_PATH"
      log_error "Private key path: $KEY_PATH"
      log_error "Certificate public key hash: $cert_pubkey"
      log_error "Private key public key hash: $key_pubkey"

      # Additional debugging
      log_error "Certificate subject: $(openssl x509 -noout -subject -in "$FULLCHAIN_PATH" 2>&1)"
      log_error "Certificate issuer: $(openssl x509 -noout -issuer -in "$FULLCHAIN_PATH" 2>&1)"
      log_error "Key info: $(openssl ec -in "$KEY_PATH" -text -noout 2>&1 | head -n3)"

      return 1
    fi
  else
    # RSA key verification using modulus
    local cert_modulus=$(openssl x509 -noout -modulus -in "$FULLCHAIN_PATH" 2>/dev/null | openssl md5)
    local cert_exit_code=${PIPESTATUS[0]}

    if [ $cert_exit_code -ne 0 ]; then
      log_error "Failed to extract modulus from certificate: $FULLCHAIN_PATH"
      log_error "OpenSSL error: $(openssl x509 -noout -modulus -in "$FULLCHAIN_PATH" 2>&1)"
      return 1
    fi

    local key_modulus=$(openssl rsa -noout -modulus -in "$KEY_PATH" 2>/dev/null | openssl md5)
    local key_exit_code=${PIPESTATUS[0]}

    if [ $key_exit_code -ne 0 ]; then
      log_error "Failed to extract modulus from private key: $KEY_PATH"
      log_error "OpenSSL error: $(openssl rsa -noout -modulus -in "$KEY_PATH" 2>&1)"
      return 1
    fi

    log_debug "Certificate modulus hash: $cert_modulus"
    log_debug "Private key modulus hash: $key_modulus"

    if [ "$cert_modulus" != "$key_modulus" ]; then
      log_error "Certificate and private key do not match!"
      log_error "Certificate path: $FULLCHAIN_PATH"
      log_error "Private key path: $KEY_PATH"
      log_error "Certificate modulus hash: $cert_modulus"
      log_error "Private key modulus hash: $key_modulus"

      # Additional debugging
      log_error "Certificate subject: $(openssl x509 -noout -subject -in "$FULLCHAIN_PATH" 2>&1)"
      log_error "Certificate issuer: $(openssl x509 -noout -issuer -in "$FULLCHAIN_PATH" 2>&1)"
      log_error "Key type: $(openssl rsa -noout -text -in "$KEY_PATH" 2>&1 | head -n1)"

      return 1
    fi
  fi

  log_debug "Certificate and key match verified successfully"
  return 0
}

# Function to ask for user confirmation
ask_confirmation() {
  [ "$FORCE_MODE" = "true" ] && return 0
  local message="$1"
  printf "${YELLOW}${message}${NC}\n"
  read -r response
  [[ "$response" =~ ^[Yy]$ ]]
}

# Function to get certificate expiration date
get_cert_expiry() {
  local cert_path=$1
  openssl x509 -enddate -noout -in "$cert_path" | cut -d= -f2
}

# Function to get certificate subject
get_cert_subject() {
  local cert_path=$1
  openssl x509 -subject -noout -in "$cert_path" | cut -d= -f2-
}

# Function to convert date to timestamp (cross-platform)
date_to_timestamp() {
  local date_str="$1"
  # Try GNU date first (Linux/macOS with GNU coreutils)
  if date -d "$date_str" +%s 2>/dev/null; then
    return 0
  # Fall back to BSD date (native macOS)
  elif date -j -f "%b %d %H:%M:%S %Y %Z" "$date_str" +%s 2>/dev/null; then
    return 0
  else
    log_error "Unable to parse date format: $date_str"
    exit 1
  fi
}

# Function to calculate days until expiration
days_until_expiry() {
  local expiry_ts=$1
  local current_ts=$(date +%s)
  local seconds_diff=$((expiry_ts - current_ts))
  echo $((seconds_diff / 86400))
}

# Function to format days with color
format_days() {
  local days=$1
  if [ $days -lt 7 ]; then
    echo "${RED}${days} days${NC}"
  elif [ $days -lt 30 ]; then
    echo "${YELLOW}${days} days${NC}"
  else
    echo "${GREEN}${days} days${NC}"
  fi
}

# Vault operations
vault_get_secret() {
  local path="$1"
  log_debug "Attempting to get secret from Vault at: $path"
  local result
  local exit_code

  result=$($VAULT kv get -format=json "$path" 2>&1)
  exit_code=$?

  if [ $exit_code -eq 0 ]; then
    echo "$result"
    return 0
  elif [ $exit_code -eq 2 ] || [[ "$result" == *"No value found at"* ]]; then
    # Secret doesn't exist, which is OK
    log_debug "No existing secret found at $path"
    return 1
  else
    log_debug "Vault get operation failed with exit code $exit_code: $result"
    return 1
  fi
}

vault_put_secret() {
  local path="$1"
  local cert_data="$2"
  local key_data="$3"

  if [ "$DRY_RUN" = "true" ]; then
    log_info "[DRY RUN] Would upload certificate to: $path"
    return 0
  fi

  log_debug "Uploading certificate to Vault at: $path"
  if ! $VAULT kv put "$path" "$cert_data" "$key_data" 2>&1; then
    log_error "Failed to upload certificate to Vault at $path"
    return 1
  fi
  return 0
}

# Main logic
log_info "Processing certificate for domain: ${YELLOW}${DOMAIN}${NC}"
log_info "Vault secret path: ${YELLOW}${FULL_SECRET_PATH}${NC}"

# Verify cert and key match
if ! verify_cert_key_match; then
  exit 1
fi

# Get local certificate information
log_debug "Getting local certificate information..."
LOCAL_EXPIRY=$(get_cert_expiry "$FULLCHAIN_PATH")
if [ -z "$LOCAL_EXPIRY" ]; then
  log_error "Failed to get certificate expiry date from $FULLCHAIN_PATH"
  exit 1
fi
log_debug "Local certificate expiry: $LOCAL_EXPIRY"

LOCAL_EXPIRY_TS=$(date_to_timestamp "$LOCAL_EXPIRY")
if [ -z "$LOCAL_EXPIRY_TS" ]; then
  log_error "Failed to convert expiry date to timestamp: $LOCAL_EXPIRY"
  exit 1
fi
log_debug "Local certificate expiry timestamp: $LOCAL_EXPIRY_TS"

LOCAL_DAYS_LEFT=$(days_until_expiry $LOCAL_EXPIRY_TS)
log_debug "Days until local certificate expiry: $LOCAL_DAYS_LEFT"

LOCAL_SUBJECT=$(get_cert_subject "$FULLCHAIN_PATH")
log_debug "Local certificate subject: $LOCAL_SUBJECT"

# Check if secret already exists in Vault
if vault_data=$(vault_get_secret "${FULL_SECRET_PATH}"); then
  log_info "Certificate for ${DOMAIN} already exists in Vault"

  # Create temporary file for Vault cert
  VAULT_CERT_TEMP=$(mktemp)

  # Extract certificate from Vault
  if ! echo "$vault_data" | jq -r ".data.data.\"$VAULT_CERT_KEY\"" > "$VAULT_CERT_TEMP"; then
    log_error "Failed to retrieve certificate from Vault"
    exit 1
  fi

  # Get Vault certificate expiry
  VAULT_EXPIRY=$(get_cert_expiry "$VAULT_CERT_TEMP")
  VAULT_EXPIRY_TS=$(date_to_timestamp "$VAULT_EXPIRY")
  VAULT_DAYS_LEFT=$(days_until_expiry $VAULT_EXPIRY_TS)

  printf "Vault certificate expires: ${BG_BLUE}${WHITE}${VAULT_EXPIRY}${NC} ($(format_days $VAULT_DAYS_LEFT) left)\n"
  printf "Local certificate expires: ${BG_BLUE}${WHITE}${LOCAL_EXPIRY}${NC} ($(format_days $LOCAL_DAYS_LEFT) left)\n"

  if [ $LOCAL_EXPIRY_TS -le $VAULT_EXPIRY_TS ]; then
    log_warn "Local certificate doesn't have a longer validity than the one in Vault"
    if ! ask_confirmation "Do you want to proceed with the upload anyway? (y/n)"; then
      log_info "Upload cancelled by user"
      exit 0
    fi
  else
    days_diff=$((LOCAL_DAYS_LEFT - VAULT_DAYS_LEFT))
    log_success "Local certificate has ${days_diff} more days of validity"
  fi
else
  log_info "No existing certificate for ${DOMAIN} in Vault"
  printf "Local certificate expires: ${BG_BLUE}${WHITE}${LOCAL_EXPIRY}${NC} ($(format_days $LOCAL_DAYS_LEFT) left)\n"
fi

# Final confirmation
if [ "$DRY_RUN" = "false" ]; then
  if ! ask_confirmation "Upload certificate to Vault at ${FULL_SECRET_PATH}? (y/n)"; then
    log_info "Upload cancelled by user"
    exit 0
  fi
fi

# Upload certificate
log_info "Uploading certificate for domain: ${DOMAIN}"
if vault_put_secret "${FULL_SECRET_PATH}" "${VAULT_CERT_KEY}=@${FULLCHAIN_PATH}" "${VAULT_KEY_KEY}=@${KEY_PATH}"; then
  if [ "$DRY_RUN" = "true" ]; then
    log_success "[DRY RUN] Certificate would be uploaded to ${FULL_SECRET_PATH}"
  else
    log_success "Certificate successfully uploaded to ${FULL_SECRET_PATH}"
  fi
else
  log_error "Failed to upload certificate to Vault"
  exit 1
fi
