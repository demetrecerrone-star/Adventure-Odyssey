# South meadow field encounter

A bounded playable first encounter is now connected to the guild field assignment. This is a training-combat slice, not the full class-skill/stat combat system.

## Current gameplay

Three original green slimes occupy (1040,2190), (1250,2260), and (1100,2430). From town, cross the west bridge and follow the south branch, then enter the grass east of the southwest path. The retry approach is (1000,2020). Enemies remain hidden and harmless before the guild assignment and stay cleared after its saved completion.

All six classes can use their equipped starter weapon with Attack or F. This shared training strike deals 12 damage, has a 0.48-second cooldown and 108-unit range, and cannot hit through terrain/props. Slimes have 36 HP, a 190-unit detection radius, 76-unit/sec chase, a 235-unit home leash, and a visible 0.65-second amber windup. Their aimed strike is avoidable by stepping away. Attacks deal 14 trial damage, with a global 0.6-second grace period preventing simultaneous hits. Returning living slimes heal at their home anchor; defeated slimes stay defeated for this attempt. Living enemies keep 42-unit foot separation. No collision tunneling, damage catch-up after an app stall, or animation-triggered extra damage.

Trial HP is explicitly labeled and starts at 100. It does not pretend that the planned character attributes, weapon upgrade formulas, skill slots or potions are already combat systems. The shared slash cue and hit flash are functional feedback; no dedicated class attack pose is claimed. Defeat opens a centered, touch-sized retry dialog; Retry or Back restores all three slimes and trial HP without item/gold loss. Menus pause the encounter. Re-entering an unfinished field attempt restarts its transient state.

The world calls Save.record_encounter_victory only after all three enemies fall. Save is the sole owner of event receipts and guild rewards. A failed victory write keeps the visible victory and retries every two seconds while the scene stays open. No per-kill loot, stat XP, Luck XP or gold is awarded by this controller.

## Art and exterior polish

The 12 original tutorial green-slime PNGs are restored byte-for-byte from the pre-rebuild archive. Four directional idle/squash/stretch poses provide idle, bouncing travel, and a telegraphed squash/lunge/recovery. These are not presented as a newly drawn dedicated attack sheet. Exact source hashes and archive provenance are in assets/monsters/provenance.json. No placeholder creature drawings or new artwork dependencies were introduced.

Eight approved existing scenery accents frame the encounter: young oak, birch, boulder, rock cluster, fern, flowers, mushrooms and grass. New solid footprints stay outside the tested route. One existing round bush moves from (1252,2329) to (1452,2529) to clear the southern approach to the second slime. Original terrain, scenery images, resident counts and building artwork are unchanged. Alpha-aware local fading now also keeps the controlled character visible behind foreground trees and scenery; masks are cached and only sampled when visual bounds overlap. Existing foot-based depth, 155-unit player speed, six-frame 9fps cadence and turn continuity remain intact.

## Verification

- Wilderness model/world suite: 641 checks, including spawn/assignment gating, chase, locked strike/dodge, leash, attack range/cooldown/line of sight, death, retry, actual swept approach routes, solid scenery, modal pause, secondary-touch cancellation and focus reset.
- Combined valid-save encounter/guild suite: 468 checks across all six classes, including actual strikes, victory write failure/retry, reload suppression and guild turn-in.
- Existing world suite: 3851 checks. Existing HUD integration: 4322 checks. Avatar turn continuity: 12128 checks. Quest save suite: 774 checks.
- Native Godot 4.6.3 / Xorg dummy / Mesa llvmpipe screenshots reviewed at 1280x720 and 844x390: meadow, windup, slash, phone HUD, defeat/retry and tree occlusion. Initial phone retry positioning and stale combat-unavailable label were fixed after visual review. Four-second native rendered motion capture covers pursuit, strike, damage and movement. This is desktop software rendering, not Android device/performance certification.
- Only three enemy controllers and shared source textures are added; 12 slime frames total about 0.49 MiB decoded RGBA. No new full-map texture or new scenery texture set. Existing bounded terrain chunk streaming remains in place.

Run `godot --headless --path . --script res://tests/wilderness_encounter_test.gd`. Native captures: `tests/wilderness_screenshot.gd`; optional `-- --motion` writes 120 rendered frames. Capture scripts use disposable valid quest saves. No APK requested or exported.
