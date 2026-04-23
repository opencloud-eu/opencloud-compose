#!/bin/sh
set -e

CONFIG_FILE="/etc/onlyoffice/documentserver/local.json"
DATA_DIR="/var/www/onlyoffice/Data"
WOPI_PRIVATE_KEY="${DATA_DIR}/wopi_private.key"
WOPI_PUBLIC_KEY="${DATA_DIR}/wopi_public.key"

if [ "${WOPI_ENABLED:-false}" = "true" ]; then
    mkdir -p "$DATA_DIR"

    if [ ! -f "$WOPI_PRIVATE_KEY" ]; then
        echo "Generating WOPI private key..."
        openssl genpkey -algorithm RSA -outform PEM -out "$WOPI_PRIVATE_KEY" >/dev/null 2>&1
    fi

    if [ ! -f "$WOPI_PUBLIC_KEY" ]; then
        echo "Generating WOPI public key..."
        openssl rsa -RSAPublicKey_out -in "$WOPI_PRIVATE_KEY" \
            -outform "MS PUBLICKEYBLOB" -out "$WOPI_PUBLIC_KEY" >/dev/null 2>&1
    fi

    WOPI_PRIVATE_KEY_CONTENT=$(cat "$WOPI_PRIVATE_KEY")
    WOPI_PUBLIC_KEY_CONTENT=$(openssl base64 -in "$WOPI_PUBLIC_KEY" -A)
    WOPI_MODULUS=$(openssl rsa -pubin -inform "MS PUBLICKEYBLOB" -modulus -noout \
        -in "$WOPI_PUBLIC_KEY" | sed 's/Modulus=//' | \
        python3 -c "import sys,binascii,base64; print(base64.b64encode(binascii.unhexlify(sys.stdin.read().strip())).decode())")
    
    WOPI_EXPONENT=$(openssl rsa -pubin -inform "MS PUBLICKEYBLOB" -text -noout \
        -in "$WOPI_PUBLIC_KEY" | grep -oP '(?<=Exponent: )\d+')

    # Merge WOPI config into local.json
    jq \
        --argjson wopiEnabled "true" \
        --arg wopiPrivateKey "$WOPI_PRIVATE_KEY_CONTENT" \
        --arg wopiPublicKey "$WOPI_PUBLIC_KEY_CONTENT" \
        --arg wopiModulus "$WOPI_MODULUS" \
        --arg wopiExponent "$WOPI_EXPONENT" \
        '.wopi.enable = $wopiEnabled |
         .wopi.privateKey = $wopiPrivateKey |
         .wopi.privateKeyOld = $wopiPrivateKey |
         .wopi.publicKey = $wopiPublicKey |
         .wopi.publicKeyOld = $wopiPublicKey |
         .wopi.modulus = $wopiModulus |
         .wopi.modulusOld = $wopiModulus |
         .wopi.exponent = ($wopiExponent | tonumber) |
         .wopi.exponentOld = ($wopiExponent | tonumber)' \
        "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"

    mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    echo "WOPI configuration injected successfully."
fi

# Hand over to the official DocumentServer entrypoint
exec /entrypoint.sh "$@"
