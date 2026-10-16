# Directional monster animation validation

Baseline: a237b6cbd4b15dd580b5dd0e65127949d0ee7523.

## Coverage

Eleven active placeholder appearances replaced: wolf, goblin, fungus, ruins_wolf,
stone_goblin, cursed_fungus, ruins_skeleton, ruins_archer, spore_bat, stone_golem,
guardian. The unused moss_slime prototype is not installed. Original tutorial
slimes and approved backgrounds, compass, characters, equipment are unchanged.

Each `assets/creatures/animated/<appearance>.png` is RGBA, 512 × 768 pixels,
with four 128-pixel frames per row. Rows: walk down/right/up, attack down/right/up.
Left mirrors right; up/down use actual separately drawn views. Feet align at
cell y=120. Nearest sampling preserves pixel-art detail. Real movement advances
walk frames; idle holds. Existing AI windup selects preparation frames and real
attack attempts select strike/recovery. Animation never deals damage or changes
attack cooldowns, collision, rewards, or AI.

## Reconstruction

Run `tools/apply_monster_animation.py` after `tools/apply_combat_polish.py`.
All three existing workflow reconstruction paths include the step. The archived
source must first receive the entire normal ordered overlay pipeline. Generated
bedroom/test changes produced by existing overlays are necessary runtime outputs,
not new changes belonging to this milestone.

## Verification

Local Godot 4.6.3 (repository CI target remains 4.7.2): editor import and 16
regression suites passed, with no SCRIPT ERROR or ERROR in final logs:
smoke, bedroom, creator_deep, opening_tutorial, guild_training, slime_ai,
extended_enemy_ai, dungeon_combat_ai, combat_polish (including readable FX),
world_expansion, monster_loot, guardian_weapons, combat_feedback,
forest_background, monster_animation, oldstone_dungeon.

`godot --headless --path . --script res://tests/monster_animation_test.gd`
checks all eleven real sheets, transparency, distinct directions/attack art,
AI walking, idle, timing, windup cancellation, stun, left flip, vertical attacks,
and death. `-- --wolf-only` narrows this test for the approved wolf preview.

Independent visual review verified all eleven sheets have no materially clipped
frames or major directional failures. Archer directional shots and Guardian rear
attack were corrected during QA. Stone goblin's fourth front-walk dagger-hand continuity was corrected before final validation.

Native rendered screenshots and emulator playthrough were NOT run: local display
creation is restricted. `tests/monster_animation_screenshot.gd` is prepared for a
working display. Sprite GIF previews are explicitly labeled as sprite previews,
not in-game captures. No APK/AAB export or remote publication was performed.

## Art provenance

Sprites were generated with the built-in image generation tool, using the
existing skeleton_warrior_walk/down_00.png as a style reference, then inspected.
The wolf identity and directional preview were approved during review. Common
prompt specification: richly shaded crisp pixel-art fantasy RPG, dark thin
contours, top-down three-quarter perspective; 24 frames in four columns/six rows;
walk down/right/up then attack down/right/up; distinct alternating footfalls;
ready/windup/strike/recovery; actual rear anatomy for north; transparent PNG;
no background, labels, grid or shadows. Species-specific prompts specified their
existing identities and weapon/attack type. Mechanical frame extraction, uniform
nearest-neighbor scaling and padding preserved source RGBA art; no procedural
replacement monster drawings were used.

## Combined final assembly

The save/progression reliability overlay is included after monster animation.
A separate clean reconstruction matches the working game.gd byte-for-byte:
8062cb5bf9006bb3f50b5b942b69f578449d6182b2ca522f6b3ba58cef4a37ec.
The workflow now restores current tracked files from the checked-out index after
unpacking the historical ZIP, before applying overlays, so stale archived copies
cannot overwrite the current scripts or tests. Workflow YAML and Python overlay
compilation checks pass. No existing tracked artwork differs from base commit.
