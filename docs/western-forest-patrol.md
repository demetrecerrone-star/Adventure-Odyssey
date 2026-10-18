# Western Forest patrol

## Quest content

After the first South Meadow reward is collected, the guild offers a Western Forest patrol. Accept it, cross the west bridge, take the northern branch of the existing road, and enter the clearing east of the first wooded bend. Two wolves occupy (660,950) and (700,1110); the return/retry approach is (850,1230). Defeat both, then return to the guild for a once-only 40-gold reward.

The progress model appends forest_patrol_active, return_guild_forest and forest_patrol_complete after the existing tutorial_complete stage. Existing version-1 quest states and completed training receipts still validate without reinterpretation or rewards being reseeded. The forest event requires west_forest_patrol; old meadow victories cannot complete it. Assignment and victory grant no currency. The final guild action plans exactly 40 character-bound gold under guild.west_forest_patrol.gold. Save owns the atomic reward transaction, conservation checks and persistent encounter receipt.

The quest log distinguishes training and forest patrol status and lists the separate earned rewards. Guild briefing, active reminder and turn-in explain the real route, reward and supplies. Used potions remain consumed after a retry; no new XP, Luck XP, randomized loot or unimplemented upgrade benefits are promised by this quest.

## Encounter and environment contract

assets/starter-region/forest_patrol.json holds the bounded two-wolf content contract: stage, event, renderer, spawns, retry point, 48 enemy HP, 18 damage, 90-unit/sec movement, 0.8-second windup, 260-unit leash, detection/range/cooldown, and an explicitly tested route. The gameplay owner loads this data; content does not duplicate AI, player health, potion consumption or reward code.

Six approved existing scenery accents frame the clearing: birch, mossy boulder, fern, mushrooms, grass and white flowers. The two solid foot-level footprints are outside the path and combat approach rings. Existing road pixels, cliff geometry, building placements, character art and the rest of the painted map are untouched. No extra full-map texture is introduced.

## Artwork audit

The wolf is the original approved Adventure Odyssey animated wolf from the archived pre-rebuild repository. The 512×768 transparent PNG is copied byte-for-byte; provenance includes the exact hash and original source path. Its 24 frames are arranged as four-frame walk down/right/up and attack down/right/up rows; left mirrors right. Every cell has alpha margins and a consistent baseline at y120. Native frame review checked walking variation, real rear anatomy, jaw windup/strike/recovery and absence of edge clipping. The renderer chooses actual attack poses and shows an amber foot-ring telegraph and health bar. It is not a procedural placeholder or an unrelated new asset.

## Content verification

The dedicated test covers legacy completion validation, acceptance gating, wrong-encounter rejection, no early payment, idempotent completion/reward plans, missing-receipt rejection, two spawn/approach circles, both-direction swept approach/retry paths, preserved 72px clearance along all five protected existing routes, scenery assets and all four-facing wolf animation states.

Native dialogue review at1280×720 and844×390 caught an unnecessarily long acceptance briefing. It was shortened and recaptured so the entire primary Accept button is visible without scrolling on phone width. Leave and reward controls remain visible. Integrated gameplay/save/abilities testing and native forest captures are performed with the combined core-combat milestone; desktop native captures do not certify Android performance. No APK is part of this content milestone.

## Combined verification results

- Forest content/navigation: 3,416 checks passed with the integrated core and all forest scenery loaded.
- Full forest integration: 678 checks passed across all six classes. Covers previous 25-gold reward preservation, failed assignment writes, real supply use, defeat/retry save failure, no consumed-potion refunds, class-skill rollback/persisted mana, actual wolf kills, failed victory retry, cleared reload, atomic 40-gold payment, late-event replay and forged/missing reward rejection. No stat or Luck changes.
- Twelve native integrated views reviewed: forest overview, windup/strike, both-handed phone HUD, both-handed quest journal and supplies panel, actual earned guild turn-in, paid state and completed journal. Actual gameplay-earned completion is asserted to produce 65 total guild gold. The supplies modal is above the HUD and both potion controls fit the phone viewport.
- Fourteen native guild-dialogue views include the new acceptance, active, turn-in and completed states at desktop and phone size. The completed forest objective is labeled Status.

Reproduce: `tests/forest_patrol_content_test.gd` and `tests/forest_patrol_integration_test.gd` headless; `tests/forest_patrol_screenshot.gd` with a native display. Capture fixtures and files are disposable; production user saves are not modified by these test scripts.
