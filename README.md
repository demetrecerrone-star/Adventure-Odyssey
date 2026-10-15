Adventure Odyssey (Godot 4.7.2)

The v0.3 Godot RPG source and artwork are stored in payload/ as 35 consecutive ZIP chunks. The Android Actions workflow reconstructs the project and builds an APK. Permanent release signing credentials are private and never committed to the repository.

## Character creator source upgrades

The archived v0.3 source is reconstructed by GitHub Actions. The build then runs
`tools/apply_title_screen.py`, `tools/apply_dabsky_title.py`, and
`tools/apply_creator_improvements.py` (in that order).

The creator upgrade adds six class descriptions, a four-direction preview,
a hair-tint selector independent of the 12 hairstyles, validated names,
an explicit confirmation step, and save/load regression tests for appearance
choices. Previously saved games without a hair-tint value default to the
original tint. This is a source upgrade; Android APK exports are manual.

The eight existing body assets are baked appearance/skin variants, **not**
independently layered skin and clothing. Separate eye colors, per-region skin
recoloring, and independently swappable clothing still require new compatible
sprite layers and should not be presented as finished.
