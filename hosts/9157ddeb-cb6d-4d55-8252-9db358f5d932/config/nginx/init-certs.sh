#!/bin/sh
set -e

if [ -z "$CERT_B64" ] || [ -z "$KEY_B64" ]; then
  echo "CERT_B64/KEY_B64 not set" >&2
  exit 1
fi

mkdir -p /etc/nginx/certs

write_pem() {
  src="$1"
  dest="$2"
  if ! echo "$src" | base64 -d >"$dest" 2>/dev/null; then
    printf "%s\n" "$src" >"$dest"
  fi
}

write_pem "$CERT_B64" /etc/nginx/certs/cert.pem
write_pem "$KEY_B64"  /etc/nginx/certs/key.pem

chown -R nginx:nginx /etc/nginx/certs
chmod 640 /etc/nginx/certs/key.pem
exec nginx -g "daemon off;"
