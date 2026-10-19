# Adventure Odyssey 0.16: optional saved login and phone usability

This release packages the approved overnight checkpoint `0d75052e65e6abd9aedd057f00aa2a0be9739ad8` with Android version code 16 and version name `0.16-remember-me`. The package remains `com.demetrecerrone.adventureodyssey`, using the existing permanent release signing identity.

## Changes
- Optional Remember me starts off. On supported Android builds it stores only a refresh token and expected account identity using AES-256-GCM with Android Keystore and a no-backup AtomicFile, through Godot's built-in Android Java bridge. Passwords are never saved; there is no plaintext fallback.
- Email-verification status refreshes automatically after successful authentication and restoration. An offline lookup retains the identity and reports unknown verification status honestly.
- All four title actions fit short landscape screens.
- Failed equipment saves remain open with an error and retry. Inventory popups resize correctly and hide the equipped weapon behind their content.
- Quest-save errors appear above dialogue options, and repeated conversations release old touch controls.

## Verification gates
CI imports and runs the full source regression suite, records native desktop captures, injects only approved public Firebase client values, exports the APK with the existing signing secret, and checks APK integrity, signature, package/version, supported architectures and Internet-only permissions. It also validates exported game resources, enabled client configuration, and Android bridge symbols for both packaged architectures, then repeats the packaged regression suite.

These checks do not prove Android Keystore encryption/decryption, restart/reboot restoration, tamper handling, removal or latency on an actual device. Desktop storage tests use mocks. Native desktop screenshots are not Android-device verification. No live account or email requests are made by these automated tests, and no external device-testing service receives the APK.

## Limits and updating
Google sign-in remains unimplemented. Progress, characters and inventory remain local; there is no cloud save, automatic merge or account ownership transfer. Install this update over the prior official version without uninstalling to retain existing local data. Keep Remember me off if you do not want durable login storage. Signing-key material and original Firebase configuration are never included in the release.

The certificate SHA-256 remains `d66e7daf0e5c7c735bf9f1c866afc204e2d0355687ac37d385cf3016e42eac36`. The published release will identify its exact source commit, successful build and APK SHA-256.
