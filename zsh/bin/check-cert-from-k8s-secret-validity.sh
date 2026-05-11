#!/bin/bash

set -eo pipefail

if [ "$1" == "" ]; then
  echo "Usage: $0 namespace/secretname"
  exit 1
fi

# Parse the namespace and secret name from the argument
NAMESPACE=$(echo $1 | cut -d'/' -f1)
SECRET_NAME=$(echo $1 | cut -d'/' -f2)

if [ -z "$SECRET_NAME" ]; then
  echo "Error: Invalid format. Please provide namespace/secretname"
  exit 1
fi

# Get the certificate from the secret
CERT=$(kubectl get secret -n "$NAMESPACE" "$SECRET_NAME" -o jsonpath='{.data.tls\.crt}' 2>/dev/null)


if [ -z "$CERT" ]; then
  echo "Error: Could not find tls.crt in secret $NAMESPACE/$SECRET_NAME"
  exit 1
fi

# Decode the base64 encoded certificate
CERT_DECODED=$(echo "$CERT" | base64 -d)

# Check certificate validity
CERT_INFO=$(echo "$CERT_DECODED" | openssl x509 -noout -text 2>/dev/null)
if [ $? -ne 0 ]; then
  echo "Error: Invalid certificate format"
  exit 1
fi

# Extract validity information
NOT_BEFORE=$(echo "$CERT_DECODED" | openssl x509 -noout -startdate 2>/dev/null | sed 's/notBefore=//')
NOT_AFTER=$(echo "$CERT_DECODED" | openssl x509 -noout -enddate 2>/dev/null | sed 's/notAfter=//')

# Convert dates to timestamp for comparison
NOW_TS=$(date +%s)

# Handle date conversion based on OS (macOS vs Linux)
# if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS date command
  # EXPIRE_TS=$(date -j -f "%b %d %H:%M:%S %Y %Z" "$NOT_AFTER" +%s 2>/dev/null)
# else
  # Linux date command
EXPIRE_TS=$(date -d "$NOT_AFTER" +%s 2>/dev/null)
# fi

# Calculate days until expiration
DAYS_LEFT=$(( ($EXPIRE_TS - $NOW_TS) / 86400 ))

# Get certificate subject
SUBJECT=$(echo "$CERT_DECODED" | openssl x509 -noout -subject 2>/dev/null | sed 's/subject=//')

# Output the results
echo "Certificate from K8s secret: $NAMESPACE/$SECRET_NAME"
echo "Subject: $SUBJECT"
echo "Valid from: $NOT_BEFORE"
echo "Valid until: $NOT_AFTER"
echo "Days left: $DAYS_LEFT"

# Return an appropriate exit code based on remaining days
if [ "$DAYS_LEFT" -le 0 ]; then
  echo "Certificate has EXPIRED!"
  exit 2
elif [ "$DAYS_LEFT" -le 30 ]; then
  echo "Certificate is expiring soon!"
  exit 1
else
  echo "Certificate is valid."
  exit 0
fi
