#!/bin/sh
set -e
if [ -z "$CERT_B64" ] || [ -z "$KEY_B64" ]; then
  echo "CERT_B64/KEY_B64 not set" >&2
  exit 1
fi
mkdir -p /etc/nginx/certs
if [ ! -s /etc/nginx/certs/cert.pem ] || [ ! -s /etc/nginx/certs/key.pem ]; then
  echo "$CERT_B64" | base64 -d > /etc/nginx/certs/cert.pem
  echo "$KEY_B64"  | base64 -d > /etc/nginx/certs/key.pem
fi
chown -R nginx:nginx /etc/nginx/certs
chmod 640 /etc/nginx/certs/key.pem
exec nginx -g "daemon off;"
