# Optional saved login: local review checkpoint

## Implemented
- Remember me is off by default. Supported Android clients can opt in while signing in or creating an account.
- Only the Firebase refresh token, expected account UID and project ID are persisted. AES-256-GCM uses a fresh Cipher-generated IV, authenticated package/project context, a non-exportable Android Keystore key and an AtomicFile in Android's no-backup directory.
- Passwords and ID tokens remain transient. There is no plaintext or software-key fallback. Desktop fixtures replace the store in memory; they do not write real credentials or call Firebase.
- Restart restoration remains unsigned until Firebase accepts the refresh and returns the expected identity. Offline failures preserve encrypted storage for retry. Revocation/wrong identity removes it. Rotation writes the replacement token, and failed writes remove stale durable state.
- Sign-out clears memory and attempts verified durable removal. A failed removal is explicitly reported and blocks account replacement. Cancellation and generation checks reject stale callbacks.
- Successful sign-in, creation, refresh and restoration schedule an automatic account lookup. Unchecked verification is described as unknown; no verification email is sent automatically.
- Guest character/progress remains independent. No cloud save, merge or ownership transfer is implemented.

## Verification and limits
Mocked session/security tests and native desktop UI captures cover the implemented flow. These do not establish Android JNI overload behavior, actual Keystore encryption/decryption, device reboot persistence, device-specific key invalidation, or startup/clear latency. Those require a separately approved future Android build and user/device testing. Crypto calls are serialized synchronously on the Godot caller thread; latency is currently unmeasured. Hardware-backed key protection is not promised.

No APK or live test accounts/emails were created for this checkpoint. The previously delivered 0.15 account test remains unchanged. The user reported successful real-phone account creation, sign-in, verification email delivery, browser verification, in-app verified status, logout/relogin and preserved character/items on 0.15.
