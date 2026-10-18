# Monster coins, character XP and Adventure Odyssey Sigils

Gold remains the existing character-bound coin wallet. Adventure Odyssey Sigils are a separate earned-only wallet. There is no cash purchase or exchange system.

Current provisional quest-monster tuning:

| Monster | Count | Gold each | Character XP each | Sigils each |
| --- | ---: | ---: | ---: | ---: |
| South Meadow slime | 3 | 3 | 10 | 1 |
| Western Forest wolf | 2 | 8 | 35 | 2 |

The five monsters award 25 gold, 100 XP and 7 Sigils in total, separately from the existing 25 + 40 guild quest payments. Level 1 requires 100 XP; each next level requires 50 more than the preceding level. The existing stat system awards 5 freely assignable points per level. Normal monster kills never award Luck XP.

Each current quest spawn has a stable `quest_v1:encounter:spawn` receipt. The save commits gold, XP, Sigils, derived level and combat resources together. A duplicate notification does nothing. Partial clears survive death/retry and reload; only undefeated monsters return. Failed reward writes pause encounter simulation until a successful retry. Future repeatable content must provide a newly verified spawn incarnation, not reuse a reload timestamp or UI request ID.

Schema 11 migration preserves the existing slot, inventory, gold, resources and Luck. Only validated completed encounter event receipts prove historical kills. Those proven kills receive the same reward receipts once, including players who already finished both assignments before this feature existed. Repeated migration/reload cannot grant them again. In-progress quests without kill evidence do not receive guessed rewards. Existing independently recorded higher levels are retained as the XP system's starting level.

The home cosmetic catalog spends Sigils through atomic ownership receipts. Preview/cancel is free. Purchasing an already owned item does not charge again; insufficient funds or save failure changes neither ownership nor wallet. Owned/default looks can be freely re-equipped. Cosmetics cannot alter equipment, combat stats, starter bindings or character identity. There is no resale/refund service.
