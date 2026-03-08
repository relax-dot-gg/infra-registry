#!/bin/bash
set -euo pipefail

if [ -z "${SA_B64:-}" ]; then
  echo "ERROR: SA_B64 not set" >&2
  exit 1
fi

echo "Writing service account"
echo "$SA_B64" | base64 -d > /app/sa.json
export GOOGLE_APPLICATION_CREDENTIALS=/app/sa.json

cd /app/packages/composites/google-weather

yarn install --immutable || yarn install
exec yarn start
