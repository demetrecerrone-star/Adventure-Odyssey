# Adventure Odyssey combat polish — first pass

October 16, 2026. Continuation of the existing top-down Godot game, not a reboot. Approved AO compass, character art, world paintings, original 18 starting skills, six mentor skills, equipment and saves are preserved.

## Enemy obstacle detours

The shared enemy move step now tries both sides when a painted-map obstacle blocks a direct move. The new code checks the half-step and destination against the world collision, maintains the original 400-unit home leash, and avoids overlap with the player and nearby living enemies. The existing AI state machine, speeds, damage and rewards are unchanged. This is local steering, not full pathfinding.

## Named visual effects

All 24 original starting and mentor skill names map to intentionally assigned lightweight Godot-drawn patterns rather than a hash. The game passes skill kind into the effect and preserves combat-zone targeting and all gameplay logic.

## Character poses

Ordinary ATTACK and successful skill casts briefly select registered walking frames as an interim strike/cast pose; worn gear, clothing, hair and direction stay aligned. Dedicated new animation sprites and art approval are still future work.

## Verification

The new combat polish regression checks actual collision-detour behavior on a Thornbrook rock, correct styles for all 24 named skills, and worn equipment synchronization for normal attacks and skill casts. GitHub Actions captures screenshots/combat_effects_starters.png and screenshots/combat_effects_mentors.png with the live Godot renderer, alongside all previous screenshots. Push builds do not export an APK.

## Dungeon attack-cycle follow-up

The shared AI still had a forest-only check after resolving a hit. In all five Oldstone maps it returned before assigning the attack cooldown and before processing the other enemies. The check now stops only when the attack replaces the world, such as when the player faints. Normal 2.25-second and Guardian 3.5-second cooldowns are preserved.

The Guardian also inherited the ordinary enemy's 133-unit windup cancellation distance despite starting attacks within 165 units and having 175-unit hit reach. Its windup now uses the existing 175-unit hit reach; stepping beyond it still avoids the attack. Ordinary enemies retain their original range.

`tests/dungeon_combat_ai_test.gd` covers attack completion, cooldown timing and multiple enemies across Thornbrook and all five Oldstone maps; Guardian reach at 150, 175 and 176 units; and stopping old-room processing after fainting. It runs in the existing validation workflow without exporting an APK.

Local verification used Godot 4.7.2 on the reconstructed project. The new test reproduced 23 failing assertions before the fix, with no unrelated runtime errors, and passed after the fix. All 40 gameplay regression scripts then passed. Android emulator verification and dedicated animation art remain pending; no APK was exported.
