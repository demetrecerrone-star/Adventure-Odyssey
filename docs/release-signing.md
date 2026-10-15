# Adventure Odyssey — Android release signing

## Status
Adventure Odyssey uses its own release signing identity. The Android build
workflow **must never silently generate a new debug key** in place of the
permanent release key; this would prevent updates from installing over previous
releases. Builds missing the three release secrets fail intentionally.

The first release-key bootstrap builds a release-signed APK, then archives the
new keystore and login information into an encrypted backup. The only
decryption key is held outside GitHub; the repository contains **only a public
encryption certificate**, never a release signing private key.

## Repository secrets required for subsequent signed builds

Go to repository Settings → Secrets and variables → Actions → New repository
secret. Add:

- `AO_RELEASE_KEYSTORE_BASE64`: the **single-line base64 encoding** of the
  recovered `Adventure-Odyssey-release.p12` signing keystore;
- `AO_RELEASE_KEYSTORE_PASSWORD`: the existing password from
  `release-credentials.txt` in the private backup;
- `AO_RELEASE_KEY_ALIAS`: `adventureodyssey`.

Do **not** publish the keystore, the base64 content, or the password into
commits, repository files, Actions logs, chat messages, or public issues.

The build automatically decrypts the base64 keystore into an ephemeral private
file, invokes Godot's `--export-release`, then verifies the final APK with
Android SDK `apksigner verify --print-certs` (v2 signature is mandatory).

## Key continuity

The keystore file, its alias and password must be retained securely outside
GitHub: their loss prevents updating existing Android installations. Do not
generate another keystore for future release builds. The release package name
must also stay unchanged.

A previously installed **debug-signed** APK may not accept an update signed
with the release key. Android enforces certificate continuity. Back up any
local saves before uninstalling a debug build.

For new release APKs, launch the workflow manually using Actions → Build
Adventure Odyssey Android APK → Run workflow after all 3 secrets are set.
Do not run another bootstrap or generate a second key.

### One-time bootstrap safety model

The special `[bootstrap release signing]` commit opt-in runs the provisioning
script. The key is generated in a temporary GitHub Actions runner, where the
release APK is signed. The keystore backup is encrypted using a new AES key,
and that AES key is wrapped to the local maintainer's RSA public key using
RSA-OAEP SHA256 before leaving the runner. The private decryption key is
**never** stored in the public repository. Restore the private backup off-runner,
store an offline encrypted backup and populate the 3 Actions secrets.

The encrypted artifact alone cannot restore a keystore unless the matching
private decryption key is available.
