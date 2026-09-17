#!/bin/zsh
# Create a stable self-signed code-signing identity in the login keychain.
# Ad-hoc signing pins TCC to the per-build CDHash; a named cert keeps the
# designated requirement stable across rebuilds.
set -euo pipefail

CERT_NAME="Triclick Local"
KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"
# System LibreSSL produces PKCS#12 that `security import` accepts.
OPENSSL="/usr/bin/openssl"

if security find-identity -v -p codesigning 2>/dev/null | grep -F "\"${CERT_NAME}\"" >/dev/null; then
  echo "✓ Signing identity already exists: ${CERT_NAME}"
  security find-identity -v -p codesigning | grep -F "${CERT_NAME}" || true
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "${TMP}/cert.conf" <<EOF
[ req ]
default_bits       = 2048
distinguished_name = dn
x509_extensions    = exts
prompt             = no

[ dn ]
CN = ${CERT_NAME}

[ exts ]
basicConstraints    = critical,CA:false
keyUsage            = critical,digitalSignature
extendedKeyUsage    = critical,codeSigning
EOF

"${OPENSSL}" req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
  -keyout "${TMP}/key.pem" -out "${TMP}/cert.pem" \
  -config "${TMP}/cert.conf" 2>/dev/null

"${OPENSSL}" pkcs12 -export \
  -out "${TMP}/cert.p12" \
  -inkey "${TMP}/key.pem" \
  -in "${TMP}/cert.pem" \
  -passout pass:triclick \
  -name "${CERT_NAME}" 2>/dev/null

security import "${TMP}/cert.p12" \
  -k "${KEYCHAIN}" \
  -P triclick \
  -T /usr/bin/codesign \
  -T /usr/bin/security

security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" "${KEYCHAIN}" >/dev/null 2>&1 || true

if ! security find-identity -v -p codesigning 2>/dev/null | grep -F "\"${CERT_NAME}\"" >/dev/null; then
  echo "✗ Cert imported but not usable for codesign yet."
  echo "  Open Keychain Access → login → Certificates → ${CERT_NAME}"
  echo "  → Get Info → Trust → Code Signing: Always Trust"
  exit 1
fi

echo "✓ Created signing identity: ${CERT_NAME}"
security find-identity -v -p codesigning | grep -F "${CERT_NAME}" || true
