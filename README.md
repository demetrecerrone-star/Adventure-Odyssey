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
The bedroom doorway now opens the **cottage foyer**, which connects to the
combined living room/kitchen and the outside entrance to Elmwatch Village.
Players may also return from Elmwatch to the cottage, and then to the only
bedroom. Existing saves remain compatible; the chest, mirror, bed, title
screen, and town/forest gameplay are preserved.

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

## Starter cottage interior art and tests (October 2026)

- The approved painted foyer is stored at `assets/home/approved_cottage_foyer.jpg` and rendered by `scripts/house_room_scene.gd` without changing its aspect ratio.
- The combined living room/kitchen is playable and currently uses the code-drawn fallback in `house_room_scene.gd`. The approved living-room painting is **not yet a checked-in file**; the scene can load it from `assets/home/living_room_kitchen.png` once its source asset is made available.
- The bedroom remains a single room with three functional, independently rendered starter-furniture sprites; alternate furniture remains future earned-in-game-currency cosmetics.
- The foyer and living room/kitchen connect through the same talk/use interaction as other game objects; players can leave for Elmwatch and return via the cottage entrance in the southern-western area of the town map.
- The kitchen pantry grants exactly one Health Potion per save and does not replenish on subsequent visits.
- `tests/starter_house_test.gd` checks paintings, round-trip navigation, furniture separation and pantry persistence. `tests/starter_house_screenshot.gd` captures rendered foyer and living room previews into the visual QA artifact without exporting an APK.

## Reconciled Elmwatch NPC and town milestone (October 2026)

The advanced Elmwatch town picture, painted interiors for the Adventurers Guild, Market, Lantern Inn and Blacksmith, and all eight existing named NPCs are now wired into the **main** build. No new NPCs or duplicated cottages were created. The newer single-bedroom + foyer + combined living/kitchen arrangement takes precedence over the older prototype cottage layout.

NPCs have a save-persistent local world clock (starting at 9 AM), directional walking animations, morning/afternoon indoor work shifts, outdoor midday breaks and evening strolls, and overnight off-scene rest. Shop staff spawn only where their schedule places them. The healer restores HP; Captain Elara can complete the persistent three-slime training goal. Dialogue and town-to-business doorways work via TALK / USE. The shops do not yet implement purchase screens.

CI smoke, starter-house, dialogue, Elmwatch visual, NPC routine/presence and indoor collision tests run against the reconstructed Godot source on every push, and CI captures five Elmwatch previews. Signed Android APK exports are still manual only. The approved living room/kitchen image still needs import; this integration leaves its temporary fallback untouched.
