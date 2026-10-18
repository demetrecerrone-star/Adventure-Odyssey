# First-assignment retail route audit

User feedback on version 0.11: the first monster assignment was difficult to get to.

## Reproduction evidence

The previous encounter tests directly advanced valid quest steps and started near the meadow. They covered combat and receipts, but did not prove a complete normal-player journey.

`retail_quest_route_test.gd` now starts a fresh character and a migrated release-0.10 schema-5 character. It withdraws and equips the starter weapon through storage buttons, reads the doorstep letter, visits every attendant through exterior/interior doors, performs the free upgrade through its selection/confirmation controls, collects both gifts, and accepts the first field assignment. Every trip uses the retail collision-resolving movement method. It then follows the marked road and reaches all three monsters with Attack enabled. It never assigns tutorial stages or teleports the player.

The original source completed this journey at 844×390. No hard state-machine or collision lock was reproduced. The user's exact stuck location remains needed before claiming that a specific reported blocker has been reproduced.

## Changes

- Ground-level gold chevrons follow collision-checked roads from guild to meadow or forest. There is no straight destination arrow through walls or river banks.
- The southern slime's approach detours east around the existing flowering shrub.
- Marks only appear for accepted assignments and disappear after completion; defeated slime branches disappear.
- Dialogue actions precede repeated objective text, keeping the Accept control immediately visible on short landscape layouts.
- Guild prerequisite wording and the Quest Log explain the unlock errands without resetting saves.
- The stale exterior “Return home here” center hint is suppressed during active assignments.
- The smith's upgrade panel describes the implemented +1 basic-strike bonus.

`quest_trail_test.gd` samples every marked segment against live world collisions, checks completed/locked-state visibility, and verifies wayfinding never changes saved progress. Native screenshots are captured by the full retail walkthrough at 844×390 and 640×360.

These are desktop native-render and source-flow checks, not Android device verification. Version 0.11's downloaded APK is unchanged by this source-only patch.
