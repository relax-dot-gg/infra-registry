#!/bin/sh
set -e

CERT_PATH="/etc/nginx/certs/cert.pem"
KEY_PATH="/etc/nginx/certs/key.pem"

mkdir -p /etc/nginx/certs

write_pem() {
  src="$1"
  dest="$2"
  if ! echo "$src" | base64 -d >"$dest" 2>/dev/null; then
    printf "%s\n" "$src" >"$dest"
  fi
}

# Prefer existing certs (e.g., written by ACME)
if [ -s "$CERT_PATH" ] && [ -s "$KEY_PATH" ]; then
  echo "Using existing cert/key from $CERT_PATH"
else
  if [ -n "$CERT_B64" ] && [ -n "$KEY_B64" ]; then
    echo "Decoding cert/key from env"
    write_pem "$CERT_B64" "$CERT_PATH"
    write_pem "$KEY_B64"  "$KEY_PATH"
  else
    echo "Waiting for certs to appear at $CERT_PATH ..."
    for i in $(seq 1 60); do
      if [ -s "$CERT_PATH" ] && [ -s "$KEY_PATH" ]; then
        break
      fi
      sleep 5
    done
    if [ ! -s "$CERT_PATH" ] || [ ! -s "$KEY_PATH" ]; then
      echo "ERROR: no cert/key available" >&2
      exit 1
    fi
  fi
fi

chown -R nginx:nginx /etc/nginx/certs
chmod 640 "$KEY_PATH"
exec nginx -g "daemon off;"
