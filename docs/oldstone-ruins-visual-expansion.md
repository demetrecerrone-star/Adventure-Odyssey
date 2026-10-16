# Oldstone Ruins playable art expansion — first implementation pass

Oldstone uses the existing top-down 2048×1280 map coordinates and leaves the starter home, Elmwatch, Thornbrook, guild, weapon proficiency and saves unchanged. The new SVG maps are native imported illustrated source files, not placeholders or screenshots. **They are a first-pass in-game artwork interpretation of the approved elaborate Oldstone concept, not a pixel-for-pixel reproduction of that composition.** Full environmental painting/detail review remains a later milestone.

## Connected playable maps
- `ruins`: illustrated outdoor ruin gate and forest path, west portal returns to Thornbrook; east route unlocks at level 3 after Guild training and enters Halls.
- `halls`: Floor 1 Crumbled Halls, with stone goblin, ruins skeleton and stone golem.
- `library`: Floor 2 Ancient Library, with ancient bookshelves, ruins archer, spore bat and cursed fungus.
- `chapel`: Floor 3 Forgotten Chapel, stained windows, stone ruins, skeleton, fungus and golem.
- `sanctum`: Floor 4 Guardian Sanctum, new crystal-lit arena and a distinct large Guardian sprite.

East-west travel routes remain in the y 510–840 band, with entrances at world-edge x~95 and x~1940. The original forest passage enters Oldstone's `ruins` scene. Oldstone entrances unlock after Guild training and level 3, with backtracking. Each floor's enemies reuse tested wander/pursuit/attack/retreat logic rather than building a separate enemy combat engine. Non-boss ruins creatures drop no Sigils. The Guardian still has an independent 10% chance to drop 5 Sigils, with the first-clear 30-Sigil Guild quest reward remaining unchanged.

## Assets
- Five real full-map SVG backgrounds in `assets/world/oldstone_*.svg`, 2048×1280.
- Nine distinct transparent SVG creature illustrations in `assets/creatures/oldstone/`. The moss slime is reserved for a later floor encounter; no fake placeholder is substituted for an absent creature.
- Reconstructed Godot build patches apply `tools/apply_oldstone_dungeon.py` after Guardian's Legacy quest changes.
- `tests/oldstone_dungeon_test.gd` checks maps and textures, all encounters, floor ordering and core reward balances.
- `tests/oldstone_screenshot.gd` captures each *playable* room through Godot, in native `screenshots/oldstone_*.png`, for visual QA.

No APK export is triggered by a push to `main`—only Godot import, tests and screenshots run.
