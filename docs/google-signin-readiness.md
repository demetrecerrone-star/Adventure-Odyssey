# Google sign-in readiness

Email/password works independently. The Google console provider being enabled does not make the current game button functional. No Google credentials, OAuth setup or live accounts were changed during this review.

## Next manual setup check
In Firebase project `adventure-odyssey-2aadf`, select Android app `com.demetrecerrone.adventureodyssey` under Project settings → General. Confirm its SHA-1 certificate fingerprint matches the permanent release certificate:

`72:C3:D1:BA:6A:F9:24:23:52:6F:34:B8:6A:4F:51:89:8D:13:54:49`

This is a public certificate fingerprint verified from the signed APK. It is not a private signing key. Odyssey's console fingerprint has not been independently verified. Do not replace the signing identity.

## Implementation still required
- Integrate Android Credential Manager / Google ID credential support through a Godot Android plugin and reviewed Gradle dependencies. The present REST-only export does not bundle this UI/SDK.
- Select the matching web OAuth client ID as the Google token audience, while verifying the Android package/certificate client. Never embed an OAuth client secret or service-account key.
- Exchange the returned Google ID credential with Firebase's `accounts:signInWithIdp`; then use the same account-session/verification/storage protections as email sign-in.
- Handle cancellation, unavailable Play services, wrong token audience, account collisions and explicit account linking. Do not silently merge local adventure progress or create a second identity when linking is needed.
- Verify the exact signed Android build on a Google-capable device. Desktop mocks cannot prove the native account chooser or provider configuration.

The current secret validator intentionally selects only email-auth public client configuration and ignores OAuth entries. No secret is read or exposed for this readiness review. A later setup/build requires the relevant user approval; no new APK was produced overnight.

## Official references
- Firebase Android Google authentication, including SHA-1 registration and Credential Manager setup: https://firebase.google.com/docs/auth/android/google-signin
- Firebase REST OAuth exchange and account-linking responses: https://firebase.google.com/docs/reference/rest/auth#section-sign-in-with-oauth-credential
- Godot Android plugin integration: https://docs.godotengine.org/en/stable/tutorials/platform/android/android_plugin.html
