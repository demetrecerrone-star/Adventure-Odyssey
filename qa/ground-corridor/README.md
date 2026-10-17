# Bounded ground corridor: isolated Godot engine QA

Source checkout: Adventure-Odyssey-Rebuild at 52bf28496f5922346043b08710f61da1b46a1f7f (v0.8). No checkout files changed. Ground package copied without editing terrain; 12 chunks, 2880×1023 at region origin (1344,768). This is not the whole region, a shipping level, or an APK. No buildings/props added. Three visual water/cliff outlines are proposed QA collision bodies only.

## Validated locally
Godot 4.6.3 headless: 12/12 checks pass; results/headless.json and log. Both full 72 px route envelopes clear real Godot physics sweeps. A CharacterBody2D with 16 px circular footprint traverses all route segments at 135 px/s without collision. Ideal route lengths/times: 1571.68 px / 11.642 s; 233.54 px / 1.730 s. Segment-end fixed-step rounding produces 702 and 105 simulated ticks. Actual wall-clock/game timing was not measured. Direct ray probes confirm all three colliders exist and reject crossing. Current joystick code is copied unchanged; full deflection and release pass.

12 decoded chunk cores and 2 px copied-neighbor gutters compare exactly. No mipmaps are generated. Sprite2D regions draw only cores, with region_filter_clip_enabled=false so the copied neighboring pixels can supply linear edge samples. Renderer seam behavior remains unverified until CI captures run.

At 1280×720, camera zoom 1 and 128 px prefetch margin, the route/full-strip camera sweep peaks at 8 resident chunks = 8.118 MiB RGBA estimate. It exercises loading all 12 and eviction. Entire supplied strip is 11.421 MiB RGBA. Figures exclude driver texture allocation, transient decode buffers, actor/HUD, framebuffer and process memory. Headless dummy renderer cannot establish VRAM usage. There is no permanent texture cache; load-on-demand is synchronous, so device hitching remains untested.

## Reserved west-shop clearance corrected
The initial guild route's 72 px envelope overlapped the shop_west reservation by 1678 raster pixels. The QA-only reservation is now retracted eastward: polygon [[1060,370],[1160,360],[1220,440],[1080,495]] becomes [[1130,370],[1160,360],[1220,440],[1130,475]]. The east edge, entrance [1155,518], both routes and all source terrain are unchanged. This is a smaller proposed lot, not a placed building or approved building design. Both 72 px route masks now have zero overlap with all seven reserved lots. See results/lot-clearance.json. Actual building-footprint fit and access still require validation when building art is placed. Original corridor art package metadata remains unchanged; this correction lives in the QA layout only.

## Explicit assumptions and limits
- Outdoor follow camera is a QA assumption: 1280×720, no smoothing, zoom 1 baseline. Existing bedroom fits its entire 1536×1024 room into the viewport and supplies no outdoor camera implementation.
- Actor is an unchanged composite of the current male-warrior idle body and armor, cropped to visible alpha bounds and displayed at 96 world px tall; original texture detail retained. Static scale marker only, no gait claim. The main walk-art work is separate.
- Foot radius 16 follows bedroom obstacle-inflation magnitude but is a new QA physics approximation. It is not an approved final outdoor hitbox.
- Proposed speed 135 follows movement-v3/speed-135.patch; patch is not applied to production.
- No navmesh/pathfinder, playable transitions, enemy safety implementation, lot collision, building occlusion or full-region claim.
- Crop boundaries are unfinished continuations. This harness intentionally does not turn them into final walls/exits.
- Zoom 1.5/2 captures test texture filtering and seams. Magnification cannot create new ground detail; source remains 1 texel/world pixel.

## Run / capture plan
Open qa.tscn for interactive WASD/joystick exploration on an authorized display. Source chunks are loaded as images directly, so no import/export is necessary.

Headless:
  godot --headless --path . --script res://src/test.gd
  python3 verify_assets.py

If HOME is read-only, point XDG_DATA_HOME, XDG_CACHE_HOME, XDG_CONFIG_HOME at writable project-local .runtime subdirectories. This only redirects logs/cache; no display access is needed.

Renderer:
  godot --path . --script res://src/capture.gd

capture.gd refuses headless. It emits six views (home, join integer/subpixel, 1.5×/2× join, plaza); compares chunked rendering to a reconstructed single-texture reference at identical camera transforms with a 2/255 channel tolerance; and emits three frames from a 60-rendered-frame seam crossing sampled at 135 px/s. Static actor remains a scale reference. Screenshot review must check edge bleed, apparent detail, scale and framing; numeric comparison alone is not visual approval. Motion sequence is deterministic capture, not a performance benchmark.

The isolated .github/workflows/ground-corridor-qa.yml runs on scoped QA-path pushes to main. The parent project ignores qa/ during import and excludes it from Android export. It has no APK, export, Android, release or publication jobs. The established Xvfb/Mesa software-renderer pattern yields real Godot raster output, not physical-GPU or Android-device evidence. Local DISPLAY is unset and no display workaround was attempted. No remote commit or workflow dispatch was performed here.

## Files to integrate
project.godot, qa.tscn, layout.json, actor-native.png, terrain/*.png, src/corridor.gd, src/touch_joystick.gd, src/test.gd, src/capture.gd, verify_assets.py, README.md. Keep results/ as an initially empty directory via .gitkeep; exclude .runtime/, .godot/, core dumps and local logs. Include workflow separately only after parent review.
