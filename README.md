# Adventure Odyssey · bedroom development milestone

A fresh, direct-source Godot 4 title-screen milestone. The earlier game remains preserved on `archive/pre-rebuild-2026-10-16` with its history.

## Scope
Landscape dusk kingdom painting, separate title and original byDABSKY artwork, animated bottom-road chase, four interactive buttons, and responsive account-preview dialogs. Guest now opens a local character creator and layered bedroom milestone. See `docs/bedroom-milestone.md` for controls, verification and remaining art dependencies. No backend, authentication, network requests or password persistence are implemented. Use dummy details in the preview forms.

## Validate
Run `godot --headless --path . --editor --quit`, then `godot --headless --path . --script res://tests/title_test.gd`. Also run `tests/creator_test.gd` and `tests/bedroom_test.gd` with the same script option.
Native captures use `godot --path . --script res://tests/title_screenshot.gd` in a supported desktop/Xvfb environment. CI uploads title, sign-in, create-account and wide-screen captures. Pushes validate only. Manual workflow dispatch or an explicitly requested commit containing `[build-title-apk]` builds the signed Android preview after validation. Ordinary commits never build an APK.

## Android
Package: `com.demetrecerrone.adventureodyssey`. Version code 5, version name `0.5-bedroom-preview`. Permanent release signing is retained via existing repository secrets; no keystores belong in the source tree. ARM64 phones, landscape orientation.

Fonts: DejaVu, licensed as described in assets/fonts/LICENSE.txt. Original generated visual assets are separate from interface elements. byDABSKY is the exact user-supplied transparent file.

## Account panel preview
The existing email/password/confirmation panel includes independent Show/Hide controls, local email/password-match checks, and always-visible close control. Enter advances fields; Escape or Android Back dismisses. Passwords are cleared on dismissal and valid preview submission. An eight-character minimum is a UI-preview rule, not a production authentication policy. Privacy Policy and Terms of Use open bundled, clearly labeled preview review drafts; no consent is collected. Opening a document clears all form entries; Back, Close, Escape and Android Back return to the originating Sign In or Create Account form with empty fields. The drafts are not final terms or a policy for an online release. Keyboard and cutout regions constrain the scrollable panel without changing the title artwork.

Headless tests cover repeated opening/dismissal, dummy-field validation, masking, focus advancement, safe-region geometry and scrolling. Native CI additionally captures normal, validation, narrow-landscape and simulated keyboard-region panels. Actual Android soft-keyboard/cutout behavior still needs device testing; simulated captures are not device verification. Ordinary source pushes run validation/capture only, not APK export.

A backend-success navigation hook returns Create Account to Sign In, carries only the email and focuses an empty password field. It is not connected to local preview validation; no successful registration is simulated.

Sign In shares password visibility and local validation, links to Create Account and both preview documents, and clearly states that password reset is unavailable.

Reciprocal Sign In / Create Account links carry only the email; passwords and visibility toggles reset on every switch.
