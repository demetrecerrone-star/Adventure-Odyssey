# Historical title-only validation

These results describe the pre-bedroom base commit d6037a6. Current bedroom validation and limitations are in `bedroom-milestone.md`.

# Title preview validation

Local Godot 4.6.3 headless import and 101 checks pass: four actual buttons, repeated modal open/close, duplicate-click guard, masked password fields, clearing dummy credentials on submit/close, truthful unconfigured-auth messaging, Android Back, Escape, responsive bounds at 1280×720, 1920×1080, 2400×1080 and 1024×768, actual mouse/touch/keyboard GUI input, separate animated runners with registered pivots and correct chase order.

Godot 4.7.2 CI passed all 101 checks and generated all eight native captures in run 38987023876. The 16:9 title, wide title and account dialogs were visually reviewed with no clipping found. Headless results are not visual approval or physical-device keyboard/safe-area testing. CI produces title, sign-in, create-account, wide title, and four chase-pose screenshots.

Art: background and wordmark approved; byDABSKY exact input bytes preserved. Chase uses four distinct generated poses with extended and passing states. Limb alternation and small-detail consistency are preview quality, not a hand-polished final run cycle.

Android update identity: same package and permanent certificate. Correct Godot version/code=4 exceeds previous APK's actual versionCode=1. Preview does not implement a game world, save migration or authenticated accounts.
