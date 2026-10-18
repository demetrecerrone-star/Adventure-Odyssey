# Hidden stick and movement correction

The released rebuild omitted the requested hidden stick entirely: no implementation or asset exists in its catalog or in the retained historical branches/payload. This restores the confirmed concept with new original twig artwork, not an assumed old item/stat specification.

One eligible existing tree is randomly selected when a character is created or a pre-v12 save migrates. Its identity is stored atomically and never rerolled on reload. There is no quest marker, minimap marker, quest objective or remote grant. The player must physically explore behind trees and use a short-range Search roots interaction. Non-selected roots yield only ordinary leaves. Once found, the world pickup is hidden permanently for that character.

The suspiciously ordinary stick is one character-bound ledger instance, usable by all six classes through an explicit unique-item exception; normal class weapons retain their restrictions. It can be equipped, unequipped and stored without duplicating or resetting the pickup. Generic drop/trade acquisition cannot create it. A failed save rolls back the claim and inventory together. Save validation rejects mismatched claim/ownership, altered provenance and duplicate copies.

Its provisional overpowered tuning is 1,000 basic strike damage before Strength/buffs: 12 normal baseline plus 988 weapon bonus. This is real encounter damage, not a preview statistic. No currency, XP, core attribute or skill benefit is invented. Appearance dyes remain independent of the weapon.

All translation speeds increase exactly 20%, from 155 to 186 logical pixels/second, in bedroom, every town interior and the outdoor scene. Keyboard and analog movement retain diagonal normalization, collision stepping and frame-time caps. Animation time is compensated for the faster travel, preserving the existing six-frame 9fps cadence and turn-phase continuity.

## Verification

- Hidden pickup/save tests: six classes, failed write, duplicate search, bound provenance, generic-grant rejection, equipment/storage/reload, actual lethal strike, v11 migration and stable selected tree.
- All three eligible search locations have collision-safe approaches. A route search from the established forest path is followed through actual `move_player` collision stepping to each location.
- Movement test checks 186px/s in bedroom/world/guild, full/half analog, diagonal normalization, keyboard input and preserved animation time.
- Native preview covers actual search/pickup, held twig in all four directions and phone inventory. Android testing remains unperformed; no Ramus upload or new APK was requested for this correction.

Final combined verification: 175 hidden-item checks, 366 real-world combat checks across six classes (actual kill receipts and removal of OP damage when swapped out), 31 movement checks, 12,128 unchanged avatar turn checks, 1,590 painted-walk checks, 334 bedroom checks, 134 inventory checks, and 2,682 tutorial-save checks passed. Native inventory detail clearly shows the real base damage and all-class eligibility. Search-location screenshots are QA spoilers and should not be used as unsolicited player guidance.
