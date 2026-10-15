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
The bedroom now loads a separate illustrated room background and interchangeable furniture sprites through `scripts/bedroom_scene.gd`.
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


## Modular starter furniture (visual milestone)

The first green oak bed, tall wooden mirror and plain wooden chest are free
and equipped on new characters. Existing saves receive the same starter set.
The new bedroom picture is intentionally empty underneath the furniture, so
recoloring, swapping and placing furniture can be built without repainting it.
Chest item storage, bed rest and mirror appearance editing continue to work.
The player can preview their current starter selections using ROOM STYLE in
the chest screen. Different bed colors, mirror shapes and chest styles are
reserved for a later in-game gold cosmetic shop; purchasing and unlock screens
are **not yet implemented**. No real-money purchases are used.

CI applies `tools/apply_home_furniture.py` after the dialogue tutorial patch
and tests the modular room using `tests/home_furniture_test.gd`.
The checked-in sprites are lightweight previews; the high-resolution source
sprites should replace the small previews before final art lock.
