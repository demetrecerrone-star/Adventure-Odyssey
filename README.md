# Adventure Odyssey · title preview

A fresh, direct-source Godot 4 title-screen milestone. The earlier game remains preserved on `archive/pre-rebuild-2026-10-16` with its history.

## Scope
Landscape dusk kingdom painting, separate title and original byDABSKY artwork, animated bottom-road chase, four interactive buttons, and responsive account-preview dialogs. Guest explains the title-only milestone. No backend, authentication, network requests or password persistence are implemented. Use dummy details in the preview forms.

## Validate
Run `godot --headless --path . --editor --quit`, then `godot --headless --path . --script res://tests/title_test.gd`.
Native captures use `godot --path . --script res://tests/title_screenshot.gd` in a supported desktop/Xvfb environment. CI uploads title, sign-in, create-account and wide-screen captures. Pushes validate only. Manual workflow dispatch builds the signed Android preview after validation.

## Android
Package: `com.demetrecerrone.adventureodyssey`. Version code 4, version name `0.4-title-preview`. Permanent release signing is retained via existing repository secrets; no keystores belong in the source tree. ARM64 phones, landscape orientation.

Fonts: DejaVu, licensed as described in assets/fonts/LICENSE.txt. Original generated visual assets are separate from interface elements. byDABSKY is the exact user-supplied transparent file.
