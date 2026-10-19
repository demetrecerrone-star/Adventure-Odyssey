# Account integration: implementation checkpoint

## Status

The delivered 0.14 APK remains unchanged. Firebase project `adventure-odyssey-2aadf` was created by the developer, who reports enabling Email/Password and Google. Billing/Spark status and key restrictions have not been independently checked. No backend configuration, credentials or live account traffic has been performed by this implementation.

The new `src/accounts/firebase_auth.gd` is a disabled-by-default REST adapter. It implements email/password registration and sign-in, verification mail and verification lookup, reset-mail request, session refresh, cancellation and logout. It stores sessions in memory only. Closing the app requires signing in again until a separately tested Android Keystore-backed token store exists. It never persists a password or token, reads a guest save, or uploads gameplay data. The title UI now has gated real account, reset and logout flows, but remains its truthful offline preview while configuration/notice review is incomplete. Mock UI tests verify cancelled callbacks, duplicate submits and unchanged guest-save bytes.

## Required activation gates

- Confirm the selected project remains on Spark with no linked billing account, trial or paid service.
- Use only the project's Firebase public client key, restricted to appropriate Firebase APIs. Never use a service-account key, private key or Gemini key.
- Review factual account/privacy notices before accepting real credentials. Current bundled documents describe offline dummy forms and cannot describe enabled accounts.
- Add the Android INTERNET permission only to the future account-enabled build. Existing 0.14 remains permission-free.
- Test real verification, reset, sign-in, refresh, logout and failure behavior against approved test accounts. Mock responses are unit tests, not live-service verification.
- Google console enablement alone does not implement Android sign-in. Keep it explicitly unavailable until Android/OAuth application setup and actual browser/SDK callback handling are complete.

## Progress safety

Existing `user://bedroom_guest_v1.json` remains the permanent local guest save. Login is an identity layer, not an implicit migration or cloud backup. Signing in, cancelling, losing connectivity, refreshing, switching accounts or logging out must not overwrite, delete, claim or merge that character or its inventory, gold, Sigils, level, quests and receipts. Any future cloud save system needs explicit account ownership, revision/conflict handling, atomic transactions and a user-visible import decision. Offline-earned currency must not be treated as server-authoritative multiplayer economy.

## Security and UX contract

Requests use fixed Google HTTPS origins, TLS defaults, no redirects, 20-second timeout and a 64KiB response limit. Passwords exist only for the immediate request and must be cleared from form fields on dispatch/cancel. No raw error body/token logging. Duplicate submits are ignored. Cancel/logout invalidate in-flight callbacks. Only a complete successful server response establishes a session; email verification requires a matching account lookup. Reset wording does not expose account existence. Auth errors leave guest play available. Runtime session expiry must refresh or require a fresh sign-in; local clocks are not a server authorization boundary.

## Provider research (official sources checked October 19, 2026)

Firebase Spark is the recommended zero-budget starting point for email/password accounts. Standard non-phone Authentication is a no-cost product; do not conflate it with the separately upgraded Identity Platform quotas. Identity Platform on Spark has a 3,000 daily-active-user limit; pricing also lists a 50,000 MAU tier. Spark email quotas include 1,000 verification and 150 password-reset emails/day, while email-link sign-in is only five/day. Project creation is usually limited to 5–10 projects per Google account. No billing card is needed for Spark. Quota exhaustion blocks the affected operation/service rather than silently charging; resets depend on the quota period. Linking billing changes the project to Blaze, so do not link it.

- https://firebase.google.com/docs/projects/billing/firebase-pricing-plans
- https://firebase.google.com/docs/auth/limits
- https://firebase.google.com/docs/auth
- https://firebase.google.com/docs/projects/learn-more

Supabase Free includes 50,000 MAU, two active free projects and 500MB database/project; inactive projects may pause after one week. Its built-in SMTP is team-address-only and two messages/hour, so it is unsuitable for public email signups without a separate mail provider. Pro starts at $25/month; not selected for this zero-budget milestone.

- https://supabase.com/pricing
- https://supabase.com/docs/guides/platform/billing-on-supabase
- https://supabase.com/docs/guides/auth/auth-smtp

PlayFab Development currently permits 1,000 lifetime player accounts/title and ten development titles, not the older 100,000-account figure in outdated references. Live pay-as-you-go has no base subscription but usage meters; Standard is $99/month. A current universal default email-send quota was not established from the official pages reviewed. It provides game services but does not turn the existing local game into an authoritative MMO automatically.

- https://developer.microsoft.com/en-us/games/products/playfab/pricing/
- https://learn.microsoft.com/en-us/rest/api/playfab/client/account-management/send-account-recovery-email

Godot's HTTPRequest supports HTTPS/REST on Android and requires the export INTERNET permission. Firebase documents public-client REST signup, sign-in, refresh and email-action endpoints, so an unofficial Godot SDK is not required. Authentication, cloud save storage and authoritative multiplayer simulation are distinct systems with separate security and cost requirements.

- https://docs.godotengine.org/en/stable/classes/class_httprequest.html
- https://firebase.google.com/docs/reference/rest/auth
- https://firebase.google.com/docs/projects/api-keys

## CI client check

The developer manually supplied `FIREBASE_CLIENT_CONFIG_JSON` through GitHub Actions secrets. The approved-check workflow validates it without logging its contents or contacting Firebase, writes only selected public identifiers to a runner temporary file, then removes that file. It does not upload the source JSON or generated config. Public keys embedded in a future APK are extractable; secret storage only protects repository/log exposure. Activation/injection into a distributed APK remains gated on provider restrictions and notice review. No secret values have been read by the assistant.

## Independent audit corrections

Configured account screens now use a factual provider/data notice draft, open at the top, rebuild verification controls from lookup results, and return to sign-in when a session expires. In-memory sessions attempt refresh before expiry, with a retry interval; expired or identity-mismatched sessions are cleared. JSON parsing does not log raw response text, and already-expiring sessions are rejected. Public Android package/certificate headers support app-restricted keys; they are not attestation. These fixes remain mock-tested and disabled for real users pending activation gates.

https://docs.cloud.google.com/docs/authentication/api-keys documents the Android headers and explicitly notes that application restrictions alone are bypassable; API restrictions and server authorization remain necessary.

## Approved 0.15 phone account test

The owner approved a signed account-test APK as an exception to the overnight no-APK constraint. The build selects only the public project ID/API key from the manually configured GitHub secret; the original Android JSON and OAuth entries are not included. The key is extractable from the APK, as normal for a Firebase public client, and does not authorize backend data access. Internet is the sole added Android permission. The source defaults remain disabled and key-free; approved builds inject the runtime configuration on the runner.

Automated packaged tests set `AO_AUTH_OFFLINE_TEST=1`, which disables the real client in the title UI; a separate no-network check verifies that the packaged configuration is enabled and structurally valid. This testing flag disables accounts only and never authenticates or grants gameplay benefits. All account-response tests use mocks. No automated account creation, sign-in, verification or recovery email is performed.

The owner will manually enter their own test credentials on their phone. The owner manually inspected a Browser key: its allowlist includes Identity Toolkit and Token Service and application restrictions were None. Matching that key to the selected Android client and reviewing the broader API list remain separate checks; the assistant has not inspected any key value. Google sign-in is still unavailable. The app displays the factual account data notice and preserves the existing local guest adventure without cloud backup or account ownership transfer. Actual phone networking, provider responses and keyboard behavior remain to be verified by that controlled test.
