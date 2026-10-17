# Title chase cycle QA

Replaces the four pose extension/passing toggle with 24 unique pose frames per character. Complete stride is 0.8 s at 30 fps; goblin starts six frames out of phase and remains 150 px ahead of the skeleton. Existing travel speed, road trajectory, scale and foot pivot are unchanged.

## Art approach
- Existing approved raster identities are preserved. Original `assets/title/{goblin,skeleton}-run.png` files remain unchanged.
- The reproducible script segments the original torso, limbs and boots; fixed-length two-bone IK creates contact, compression, passing and swing poses. The source passing pose provides neutral shin and boot textures.
- Far legs are shaded for separation. The sword and gripping hand share one rigid source layer, so they cannot separate or change hands.
- This is cutout articulation, not newly painted anatomy or generated frame replacements. No new image-generation prompt was used.

## Verified
- Headless Godot title regression: 272 checks, zero failures (`title-test.log`).
- `python tests/title_cycle_test.py`: 24 unique images each; 6 x 4 atlas; constant bone lengths; alternating support and airborne intervals; support foot ground height constant; planted foot world-x error below 0.001 px; no frame clipping.
- Each foot's stance is 0.288 s. Backwards source-foot motion cancels the unchanged 112 px/s title travel during contact.
- Sword hand-to-hilt/hand-to-tip distance drift below 0.000001 px. Wraparound ankle and sword movement are no larger than normal adjacent steps.
- Inspected both 24-pose contact sheets and actual display-scale frame. The fixed pivot avoids whole-body registration jumps; silhouette and boot connections remain legible at title size.
- Background, wordmark, branding, buttons, menu layout and original source atlases have no diff.

## Review files
- `goblin-contact-sheet.jpg`, `skeleton-contact-sheet.jpg`: every pose, enlarged.
- `chase-cycle.gif`: enlarged looping articulation preview.
- `chase-runtime-scale.gif` / `.png`: actual title sprite scales and 150 px spacing with runtime phase offset, on a neutral ground line. This is a composited asset preview, not a device screenshot.
- `*-kinematics.json`, `skeleton-grip.json`: frame geometry used by regression checks.

Android APK motion review is still needed for final visual acceptance. This environment has no graphical display, so no new graphical runtime screenshot was claimed. A first Godot invocation without a writable data directory crashed; rerunning with isolated writable HOME/XDG directories passed. The test exits with the pre-existing Godot PagedAllocator shutdown warning after its PASS result.
