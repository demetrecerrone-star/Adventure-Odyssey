# First field assignment

Current wilderness behavior is documented in [Respawning wilderness](respawning-wilderness.md). The initial quest-gated/permanently cleared encounter behavior below is historical.
The existing preparation sequence remains unchanged. After the keepsake errand,
the receptionist now offers **Clear the South Meadow**. Accept it at the guild,
equip a weapon, and cross the west bridge, follow the south branch, and clear the three slimes east
of the meadow trail. The encounter
controller records the completed group; return to the receptionist to finish
training and collect **25 gold**. This is provisional milestone balance.

## Save and reward contract

- Existing v9 `first_combat_pending` saves load unchanged and can accept the new
  assignment. The permanent guest save path and character identity are unchanged.
- `record_encounter_victory("south_meadow_slimes")` is a trusted gameplay call,
  never a dialogue action. It requires an active assignment and world location.
- `encounter_is_complete()` reads the same permanent event receipt. A cleared
  group cannot respawn, award again, or become incomplete on reload.
- The controller must call victory only after all three enemies are defeated.
  Defeat and interrupted fights do not grant completion. Transient encounter
  state can reset for a retry; persistent belongings are untouched.
- Victory and final payment each save atomically with rollback on disk failure.
  The controller must retain a retry path if victory saving fails.
- Only the guild turn-in grants money. Its reward receipt permits exactly 25
  additional wallet gold; conservation includes chest funds and verified shop
  spending. There is no gold transfer operation.
- Starter goods, shop goods, tutorial potions and keepsake remain character-bound.
  This quest grants no character levels, skill points or Luck XP. Empty/reopened
  storage chests are not loot events.

## Verification

`first_combat_quest_test.gd` covers all six classes, legacy pending saves,
wrong-stage/location/unknown encounters, interrupted fights, duplicate and late
callbacks, save failure rollback, exact payment, spending above the original
100-gold budget, corruption, ownership, and unchanged Luck metadata.
`tutorial_flow_test.gd` covers every ordered step and offered dialogue choice.
`first_combat_quest_screenshot.gd` captures the four new guild states at 1280×720
and 844×390, including touch-sized choices and accessible Leave controls.

Headless tests are not Android device verification. Native captures use desktop
Godot with software OpenGL. Combat-controller and end-to-end scene tests supplement
the save boundary tests; see the wilderness milestone notes for combat controls
and environmental placement.

Local verification before integration: 774 new quest-save checks; 1,154 quest
planning/dialogue checks; 2,682 tutorial-save checks; 432 menu checks; 341
stat-save checks; 294 stat-model checks; 357 shop-save checks; 81 tutorial-scene
checks; 4,322 HUD integration checks; 1,489 HUD checks; 128 inventory-panel checks.
All passed on Godot 4.6.3. Eight new native dialogue captures were generated and
phone briefing/turn-in images were visually reviewed.

Combined integration verification: 480 checks pass across all six classes using
actual world strikes, valid quest saves, blocked attacks while unequipped/in-menu,
defeat/retry, victory write failure/retry, cleared reload, and real guild dialogue
turn-in. Native scene playback adds two verified phone captures of completion
and the quest log (470 checks at capture time). A blocked attack approach found by this test was
fixed by moving an existing bush intact to the meadow perimeter.

Final merged regression: all 34 headless suites passed. Contextual Use is hidden
when no interaction target is nearby during the field assignment, preserving
the center of the fight; it returns at real interactables. Updated phone combat
captures were reviewed. No APK was built and no signing/package configuration
was changed.
