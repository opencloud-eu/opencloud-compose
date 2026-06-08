#!/bin/sh
set -e

SECRETS_DIR=/config/secrets
JWKS_KEY="${SECRETS_DIR}/oidc_jwks.pem"

mkdir -p "${SECRETS_DIR}"

# Auto-generate the OIDC JWKS RSA private key on first startup if not present.
# Authelia uses this key to sign OIDC identity tokens.
if [ ! -f "${JWKS_KEY}" ]; then
    echo "Generating OIDC JWKS RSA private key..."
    openssl genrsa -out "${JWKS_KEY}" 4096
    echo "OIDC JWKS RSA key generated at ${JWKS_KEY}"
fi

# Hand off to the default Authelia entrypoint
exec authelia "$@"
