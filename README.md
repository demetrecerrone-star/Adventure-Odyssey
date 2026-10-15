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

## Playable starter bedroom (tutorial milestone one)

After character confirmation, **new games** now awaken in a pixel-art bedroom.
The house interior is drawn dynamically by `scripts/bedroom_scene.gd`.
Players can walk around the furniture, rest at the bed, transfer backpack items
into persistent home storage, and revise their appearance at a mirror.
The bottom doorway marks the **next** milestone (hallway, kitchen, living room,
front door, and then Elmwatch Guild). It currently displays a transition message;
the rest of the cottage is not yet implemented. Existing saves remain compatible,
and the title screen and town/forest systems are unchanged.

`tools/apply_bedroom_tutorial.py` installs this after the creator patches
during CI and manually requested Android exports. CI also runs
`tests/bedroom_test.gd` and captures `screenshots/starter_bedroom.png`
with the native Godot renderer. Push events do not export an APK.
