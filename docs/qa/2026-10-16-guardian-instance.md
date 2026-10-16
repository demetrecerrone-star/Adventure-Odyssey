# Guardian story instance and repeat encounter

## Behavior

- A character's first successful Guardian fight completes the personal story encounter. Entering and leaving before victory or fainting does not consume it.
- The completed story room stays empty until the character leaves it. Saving and reloading in that cleared room does not turn it into the repeat encounter.
- Returning after departure uses the regular repeatable Guardian. The existing 60-second cooldown measured from each victory still applies, including the first victory. Waiting in a regular room can spawn the next eligible encounter.
- Main-quest completion and claiming its unique reward are independent. Captain Elara's unclaimed reward remains available once; it does not prevent regular return fights.
- Existing stats, visuals, 100-gold first-clear bonus, regular payouts and Sigil rates/quest amounts are unchanged. This work does not resolve or change the separate 30-Sigil reward discussion.
- Older cleared saves without timestamps are eligible for regular encounters. Existing ready/claimed markers also establish story completion; an old relic is not duplicated by the claim.

## Implementation and reconstruction

`guardian_defeated` continues to represent permanent story completion; `guardian_quest_state` continues to represent the independent Guild claim. New persisted `guardian_story_exit_pending` keeps the cleared story visit empty across reload and is erased upon entry to another map. Each spawned boss is tagged `guardian_encounter` as story or regular, without changing combat or art. Duplicate spawn calls cannot create multiple live Guardians.

Apply `tools/apply_guardian_instance.py` after save reliability and touch input overlays. All three reconstruction paths in the workflow include it, and both validation jobs include the new runtime suite. The overlay is idempotent. Do not substitute the generated whole game script for the repository's reconstruction process.

## Verification

Godot 4.6.3 headless: new `guardian_instance_test.gd` passes first entry, unfinished departure, faint/retry, pre-victory reload, duplicate death, no respawn in the cleared story instance, cleared-instance reload, return cooldown, unclaimed-reward regular encounters, ordinary repeat gold, repeat spawn cooldown, delayed claim, claim reload protection, and old save migration. Existing world expansion, monster loot, Guardian weapons, dungeon combat AI, save reliability and oldstone dungeon tests also pass. Logs were scanned for runtime errors.

Repository target remains Godot 4.7.2. No display/device visual acceptance, export, APK or live multiplayer validation is claimed. This is per-character save-state instancing in the current single-player game, not a networking implementation.
