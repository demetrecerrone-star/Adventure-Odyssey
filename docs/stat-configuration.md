# Core stat configuration

## Approved accounting

Every class starts at level 1 with STR, AGI, VIT, INT, WIS and LUK equal to **10**. Class, appearance, equipment and tutorial progress do not alter those baselines. Every level above 1 contributes **5 freely assignable points**. A player may place all available points into one attribute, split them among attributes, or leave them unspent. Assigning points does not change the character's class, class equipment restrictions or starter weapon.

The current game has no XP, combat or legitimate level-up source. New and migrated characters consequently stay at level 1 with zero earned points during normal play. The Stats page must not include a grant-points, debug-level or simulated level-up control. Completing tutorial errands, buying items, reloading a save and entering another scene do not award levels or points.

The authoritative implementation is `src/character_stats.gd`. The six `KEYS`, `LABELS` and `DESCRIPTIONS` define display metadata; `BASE_ATTRIBUTE = 10` and `POINTS_PER_LEVEL = 5` define the approved accounting. These two rules require an explicit save migration if changed, because earned balances are derived using them. `MAX_LEVEL = 1000` is a bounded serialization guard, not an announced gameplay cap or XP curve.

## Persistent state and safety

The permanent local guest file remains `user://bedroom_guest_v1.json`. Save schema **8** adds a nested `stats` object:

- `version`: stat schema 1
- `level`: integer 1 or greater, within the serialization bound
- `revision`: nonnegative integer incremented on each successful stat allocation or level increase
- `allocations`: exactly six uppercase keys, each holding a nonnegative integer

Attribute values are `10 + allocations[key]`. Total earned points are `5 × (level − 1)`. Unspent points are earned points minus the sum of all allocations. Validation enforces this invariant; the balance is never independently incremented or persisted. This avoids duplicate level awards and incompatible duplicated balance fields.

A model state must have exactly those four fields. Missing, unknown, negative, fractional, nonfinite, boolean or malformed values are rejected. JSON whole-number floats are accepted because Godot's JSON loader returns numbers as floats. Current-schema saves with missing or invalid stats are rejected without rewriting the file or modifying the live session.

Migration from versions 1–7 adds level-1 baseline stats only when no stat object exists. Existing valid stat metadata in downgraded metadata-bearing backups is preserved; malformed supplied stats are rejected. The existing inventory/tutorial migrations still run as appropriate. Ledger-bearing saves retain character identity and class, exact item instances and provenance, equipment, upgrade entitlements, tutorial stage and receipts, gold, purchase receipts, and location. Migration is validated and written before replacing live state. Reloading it does not grant anything again. As with other local save data, schema validation is not cryptographic anti-cheat and cannot prove an edited legacy file's historical authenticity.

## Save API and menu integration

- `get_stat_summary()` returns a detached dictionary with `ok`, `code`, `message`, `level`, `revision`, `earned_points`, `spent_points`, `unspent_points`, `attributes`, `allocations`, `planned_effects` and `effects_status`. Every operation requires a valid complete live save.
- `preview_stat_allocation(deltas, expected_revision)` validates a proposed allocation and returns detached proposed values. It performs no writes and does not expose the candidate state. A sparse dictionary or all six keys are accepted; values must be whole nonnegative amounts, total positive and within the unspent balance.
- `allocate_stat_points(deltas, expected_revision)` repeats the authoritative checks, then persists the entire transaction atomically. The successful result has `code = allocated` and `points_assigned`. A stale revision is rejected before mutation. Repeated taps with the same revision cannot assign twice, including after reload. The revision belongs to stat state; unrelated inventory/location updates do not invalidate a still-current stat draft.
- `advance_character_level(target_level, expected_revision)` is an unconnected future gameplay/service boundary. A future progression system must first establish a legitimately earned target level. An increase awards exactly five points for each newly crossed level and preserves all previous allocations. The current level returns an idempotent no-op with `duplicate = true` and `points_awarded = 0`, with no revision change or write; a lower target or stale revision is rejected. No current gameplay/UI code calls this method. Isolated test fixtures call it to test the allocation flow without inventing live XP progression.

The menu owns a local draft and calls preview, then requires explicit confirmation before calling allocation. Cancelling, dismissing, switching pages or viewing effects does not save allocations. The Save service uses the existing temporary-file/rename transaction: any failed temporary write or final rename restores all prior memory, including the stat revision, and preserves the prior disk file. An exact retry after failure can succeed. Errors include `stale_revision`, `insufficient_points`, `invalid_allocation`, `unknown_stat`, `empty_allocation`, `invalid_save` and `save_failed`.

## Provisional derived-effect previews

These values are **planned, configurable previews**, not active combat benefits. `effects_status` is `planned`. No movement, combat, hit roll, damage, potion, HP/MP resource, recovery timer, critical hit or loot system consumes them yet. In particular, there is no current-HP/current-mana state or bar and no invented XP curve. The existing +1 starter weapon remains provenance/upgrade metadata; it does not add an undocumented numeric bonus to these previews.

All provisional coefficients are centralized in the model's `TUNING` dictionary. Changing those coefficients changes computed previews without changing persisted allocations. For an attribute A, let `x = max(A − 10, 0)` and `f(A) = x / (x + 100)`. The scale 100 is configurable and produces diminishing returns for percentage-based effects.

| Stat | Preview field | Provisional formula | Meaning / bounds |
| --- | --- | --- | --- |
| STR | `physical_power` | `2 × STR` | Planned physical power, no damage consumer |
| AGI | `accuracy_chance` | `0.90 + 0.09 × f(AGI)` | Fraction; approaches 99% |
| AGI | `auto_dodge_chance` | `0.05 + 0.30 × f(AGI)` | Fraction; approaches 35% |
| VIT | `max_hp` | `50 + 5 × VIT` | Planned maximum HP |
| VIT | `resilience` | `0.30 × f(VIT)` | Planned fractional damage reduction; approaches 30% |
| INT | `spell_power` | `2 × INT` | Planned spell power, no damage consumer |
| WIS | `max_mana` | `20 + 3 × WIS` | Planned maximum mana |
| WIS | `mana_recovery_per_second` | `0.1 × WIS` | Planned mana recovered per second; no running recovery |
| LUK | `critical_chance` | `0.05 + 0.25 × f(LUK)` | Fraction; approaches 30% |
| LUK | `rare_drop_multiplier` | `1 + 0.50 × f(LUK)` | Relative multiplier on a future base probability; approaches 1.5× |

The percentage fields additionally clamp to `[0, 1]`. Their configured caps are approached asymptotically and never reached at any finite legal allocation. Luck's rare-drop multiplier is **not** a 100% base drop chance and does not imply an absolute percentage-point bonus. A future loot consumer must compute `clamp(base_probability × rare_drop_multiplier, 0, 1)` and validate the base probability before use. There is currently no loot table or drop consumer to wire.

At the common all-10 baseline, the previews are physical power 20, spell power 20, maximum HP 100, maximum mana 50, mana recovery 1/s, accuracy 90%, automatic dodge 5%, resilience 0%, critical chance 5%, and rare-drop multiplier 1×. There are no class-exclusive coefficients or hidden class bonuses.

## Verification

- `tests/character_stats_test.gd` covers baseline/accounting, all-six free allocation, preview isolation, malformed inputs and state, monotonic and repeated levels, exact point budgets, effect ownership and diminishing-return caps.
- `tests/stat_save_test.gd` covers every class, explicit allocation and reload, stale/double-tap rejection, cancelling/preview isolation, whole-save preservation, both I/O failure stages and retries, failed-level rollback, current-schema corruption, and versions 1–7 migration with tutorial/shop/upgrade preservation and no duplicate grants.
- Existing tutorial, shop, HUD and inventory tests verify that adding stats does not change their accounting or behavior.

## UI and native review contract

The Stats menu keeps a local +/- draft, then displays a separate review before Confirm. Cancel, page changes and dismissal discard unsaved points. The fixed footer stays outside the scroll region on 844×390 phones and 1280×720 views in either handedness. Character details show current saved values; HUD displays saved level while XP and current HP/MP remain unavailable. No stat maxima are presented as current health.

`tests/stat_panel_test.gd` exercises actual allocation callbacks, failure, stale drafts, repeated confirmation, cancellation, touch ownership and responsive geometry. `tests/stat_screenshot.gd` validates and captures 24 isolated desktop/phone states; its level-2 fixtures exist only in the capture script. Native visual review is required after CI before calling the checkpoint verified.
