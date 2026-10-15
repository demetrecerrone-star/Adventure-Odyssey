#!/usr/bin/env bash
# One-time release signing bootstrap. Never commit or print the generated private key.
# The artifact contains only a public APK plus an ENCRYPTED backup.
# The decryption private key is intentionally never present in GitHub.
set -euo pipefail
umask 077

if [[ "${AO_BOOTSTRAP_REQUESTED:-}" != "true" ]]; then
  echo "Release key bootstrap must be explicitly requested by the build commit." >&2
  exit 1
fi

keydir="$(mktemp -d /tmp/adventure-odyssey-release.XXXXXXXX)"
trap 'rm -rf "$keydir"' EXIT

keyfile="$keydir/Adventure-Odyssey-release.p12"
credentials="$keydir/release-credentials.txt"
alias_name="adventureodyssey"
store_password="$(openssl rand -hex 32)"
echo "::add-mask::$store_password"

keytool -genkeypair -noprompt \
  -keystore "$keyfile" \
  -storetype PKCS12 \
  -storepass "$store_password" \
  -keypass "$store_password" \
  -alias "$alias_name" \
  -keyalg RSA -keysize 3072 -sigalg SHA256withRSA \
  -validity 12000 \
  -dname "CN=Adventure Odyssey,OU=Android,O=Adventure Odyssey,C=US"

{
  echo "AO_RELEASE_KEY_ALIAS=$alias_name"
  echo "AO_RELEASE_KEYSTORE_PASSWORD=$store_password"
  echo "AO_RELEASE_KEYSTORE_TYPE=PKCS12"
  echo "Keep this file and the release keystore private. Upload the keystore's base64"
  echo "and the alias/password to GitHub Actions repository secrets for future builds."
} > "$credentials"

# Public certificate fingerprint is safe to include in build logs.
keytool -list -v -keystore "$keyfile" -storetype PKCS12 \
  -storepass "$store_password" -alias "$alias_name" | \
  grep -E 'Alias name:|SHA256:|Valid from:' || true

export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$keyfile"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$alias_name"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$store_password"

echo 'Exporting newly release-signed APK (NOT a debug signature).'
godot --headless --path . --export-release Android build/Adventure-Odyssey-release.apk

apk="build/Adventure-Odyssey-release.apk"
test -s "$apk"

# Encrypt the private keystore *before* it leaves the runner:
# fresh random AES key + RSA-3072 OAEP wrapping to the trusted public key.
# Never upload either the plaintext signing key or its plain credentials.
archive="$keydir/private-release-backup.tar.gz"
tar -czf "$archive" -C "$keydir" \
  Adventure-Odyssey-release.p12 release-credentials.txt
openssl rand -hex 32 > "$keydir/backup-aes-key.txt"

openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt \
  -in "$archive" \
  -out build/Adventure-Odyssey-Release-Backup.tar.gz.enc \
  -pass "file:$keydir/backup-aes-key.txt"

openssl pkeyutl -encrypt -pubin \
  -inkey .github/ao_release_backup_public.pem \
  -pkeyopt rsa_padding_mode:oaep \
  -pkeyopt rsa_oaep_md:sha256 \
  -in "$keydir/backup-aes-key.txt" \
  -out build/Adventure-Odyssey-Release-Backup-Key.enc

# Verify APK signing with the SDK tool in the Godot Android CI image.
signer="$(find /usr/lib/android-sdk/build-tools -maxdepth 3 -type f -name apksigner | sort -V | tail -n 1)"
test -x "$signer"
"$signer" verify --verbose --print-certs "$apk" | tee build/Release-APK-Signature.txt
grep -Fq 'Verified using v2 scheme (APK Signature Scheme v2): true' build/Release-APK-Signature.txt

sha256sum "$apk" > build/SHA256SUMS.txt
echo 'Created a release-signed APK, plus a private-key backup encrypted to the transport public key.'
