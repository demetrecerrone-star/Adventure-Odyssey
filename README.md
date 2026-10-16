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
- The exact approved painted living room/kitchen is now committed at `assets/home/living_room_kitchen.png` and loads directly through `house_room_scene.gd` (no procedural fallback needed).
- The bedroom remains a single room with three functional, independently rendered starter-furniture sprites; alternate furniture remains future earned-in-game-currency cosmetics.
- The foyer and living room/kitchen connect through the same talk/use interaction as other game objects; players can leave for Elmwatch and return via the cottage entrance in the southern-western area of the town map.
- The kitchen pantry grants exactly one Health Potion per save and does not replenish on subsequent visits.
- `tests/starter_house_test.gd` checks paintings, round-trip navigation, furniture separation and pantry persistence. `tests/starter_house_screenshot.gd` captures rendered foyer and living room previews into the visual QA artifact without exporting an APK.

## Reconciled Elmwatch NPC and town milestone (October 2026)

The advanced Elmwatch town picture, painted interiors for the Adventurers Guild, Market, Lantern Inn and Blacksmith, and all eight existing named NPCs are now wired into the **main** build. No new NPCs or duplicated cottages were created. The newer single-bedroom + foyer + combined living/kitchen arrangement takes precedence over the older prototype cottage layout.

NPCs have a save-persistent local world clock (starting at 9 AM), directional walking animations, morning/afternoon indoor work shifts, outdoor midday breaks and evening strolls, and overnight off-scene rest. Shop staff spawn only where their schedule places them. The healer restores HP; Captain Elara can complete the persistent three-slime training goal. Dialogue and town-to-business doorways work via TALK / USE. The shops do not yet implement purchase screens.

CI smoke, starter-house, opening-tutorial, dialogue, Elmwatch visual, NPC routine/presence and indoor collision tests run against the reconstructed Godot source on every push, and CI captures the Elmwatch and house visual previews. Both approved cottage paintings are now checked into `main` and have passed Godot import and gameplay validation. Signed Android APK exports are still manual only.

## Approved living-room alignment and guided first day (October 2026)

The exact approved `living_room_kitchen.png` was recovered from the Adventure Odyssey Library and checked in as unmodified, original PNG binary content at `assets/home/living_room_kitchen.png`. Godot renders this painting directly. No new artwork was generated or substituted. Living-room collision zones now match the approved hearth, sofa, dining table, and kitchen counters, with the foyer return at the bottom-center doorway. The **one-bedroom** floor plan is unchanged.

`tools/apply_opening_tutorial.py` adds first-day journal improvements and saved contextual guidance for chest, mirror, foyer, pantry, Elmwatch, Guild and training. Players can explore out of order and revisit their home. `tests/opening_tutorial_test.gd` exercises this path, save/load and existing Guild NPCs. APK exports remain manual.

## First Guild assignment and Thornbrook field tutorial (October 2026)

Captain Elara now offers an **optional explicit ACCEPT QUEST** choice in the established NPC dialogue panel. Declining or asking for advice does not accept the mission. Acceptance and progress are saved. The first visit to Thornbrook explains attacks and cooldowns, Agility dodging, HP, potions and safe retreat with a four-page Adventurer's Journal. The existing four slimes, three-hit starter combat, XP/gold drops and free level-up stat points are unchanged. The HUD tracks progress capped at 3/3. A third kill triggers a return-to-Guild journal; Captain Elara grants **20 gold plus one Health Potion once** upon reporting, with backward-compatible completion for saves that already killed three slimes before the explicit acceptance flag existed. This is single-player tutorial work only; merchant interfaces and MMORPG networking are deferred. `tests/guild_training_test.gd` checks offer/decline, persistence, cooldown, combat damage, kill counting, reward idempotence and cottage regression. `tests/guild_training_screenshot.gd` captures the actual Godot Guild offer and Thornbrook screens. Android APK export remains manual.

## Approved Thornbrook Forest background (October 2026)

The new hand-painted top-down forest with the clear west-east trail, rocky borders, fallen logs and open combat clearings has been approved and imported as a high-quality JPEG at `assets/world/thornbrook_forest_approved.jpg`, scaled to 2048 × 1280 without distorting its proportions. The `tools/apply_forest_background.py` reconstruction step replaces the old forest background reference and adds conservative solid regions for major trees and rocks. Four existing green slimes occupy reachable clearings. The western trail remains the exit back to Elmwatch. All prior combat, NPC, save, quest, character and single-bedroom systems remain intact. The `tests/forest_background_test.gd` checks the actual texture, scale, movement, combat spawn locations and westward return. `tests/guild_training_screenshot.gd` captures the updated forest gameplay in the normal screenshot artifact; Android APK export remains manual.

## Thornbrook combat readability milestone (October 2026)

The original slimes and 3-kill Guild assignment now have readable in-game feedback: health bars above each living slime, a gold targeting ring on the nearest slime in attack range, a red warning ring when a close slime is about to attack, and floating damage/dodge numbers. The TALK/USE-side HUD prompt reports the selected slime's current HP, or guidance when out of range. The existing 35-HP slimes, 0.5-second ATTACK cooldown, Agility dodging, XP/gold, free stat allocation, save data, and all home/NPC systems are unchanged. `tools/apply_combat_feedback.py` runs after the forest artwork patch; `scripts/slime_combat_indicator.gd` draws the visual layer separately from character sprites. `tests/combat_feedback_test.gd` verifies bar changes, target selection, warning timing, hit numbers and leaving the forest. The native Thornbrook screenshot includes a real ATTACK hit. No APK is auto-generated.

## Slime behavior milestone (October 2026)

The four Thornbrook green slimes now use a lightweight independent state machine instead of standing still and attacking every 2.1 seconds in unison. Each slime wanders near its original clearing; pursues a player within roughly 275 map units; shows a visible windup before a 5-HP attack with the existing Agility dodge chance; retreats briefly when below 12 HP; and returns toward its home clearing when its leash is exceeded. Movement checks painted-forest collision before each step. Dead slimes do not wander or respawn during the current visit. Their existing 35 HP, XP/gold drops, Guild quest and HUD health bars are untouched. The combat feedback's warning ring now uses the actual per-slime windup. `tests/slime_ai_test.gd` covers wandering, chase, telegraph, cooldown, retreat, leash, death and cleanup. The APK remains on hold.
