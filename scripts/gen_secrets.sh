#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

TS=$(date +%m%d%Y_%H%M)
if [ -f .env ]; then
  mv .env .env_${TS}
  echo "Existing .env moved to .env_${TS}"
fi

rand_b64() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 32
  else
    head -c 32 /dev/urandom | base64
  fi
}

SESSION_SECRET=$(rand_b64)
STORAGE_KEY=$(rand_b64)
JWT_SECRET=$(rand_b64)

cat > .env <<EOF
AUTHELIA_SESSION_SECRET=${SESSION_SECRET}
AUTHELIA_STORAGE_KEY=${STORAGE_KEY}
AUTHELIA_JWT_SECRET=${JWT_SECRET}
# Optional SMTP placeholders (leave commented unless you configure SMTP):
# SMTP_HOST=
# SMTP_PORT=
# SMTP_USER=
# SMTP_PASSWORD=
# SMTP_SENDER=
EOF

echo ".env generated (do not commit this file)."
