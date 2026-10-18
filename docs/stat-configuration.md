# Core stat configuration

## Approved accounting

Every class starts at character level 1 with STR, AGI, VIT, INT, WIS and LUK equal to **10**. Class, appearance, equipment and tutorial progress do not alter those baselines. Character levels above 1 each contribute **5 freely assignable points**, usable only for **STR, AGI, VIT, INT and WIS**. A player may place all available points into one eligible attribute, split them, or leave them unspent. **Luck cannot receive free stat points, including a zero-valued LUK entry in an allocation request.** It grows through its separate earned-XP progression.

The current game has no character XP/level-up source or loot/refill event source. New and migrated characters therefore have character level 1, zero free points, Luck 10, and **0 / 100 Luck XP toward Luck 11** during normal play. No menu grants levels, points or XP. Tutorial errands, purchases, storage-chest opening or transfers, changing scenes, and reloads do not award either kind of progression. Assigning points never changes class or class equipment restrictions.

The authoritative implementation is `src/character_stats.gd`. `KEYS` contains all six display attributes; `ALLOCATABLE_KEYS` contains only the five free-point attributes. `BASE_ATTRIBUTE = 10` and `POINTS_PER_LEVEL = 5` define the approved character-point accounting. Changing these accounting rules requires an explicit save migration. `MAX_LEVEL = 1000` is a bounded character-level serialization guard, not an announced gameplay cap or XP curve.

## Independent Luck progression

Luck starts at value 10. Completing the first 100 earned Luck XP raises it to 11; the next threshold is 125 XP, then 150, then 175, and so on. `LUCK_TUNING` contains the provisional `first_threshold = 100` and `threshold_increment = 25`. Overflow carries forward. For internal rank `r`, starting at 1, the current threshold is `100 + 25 × (r − 1)`, and Luck's value is `10 + r − 1`. The menu displays the attribute value, such as Luck 10, and current/required XP; it must not confuse internal rank 1 with attribute value 10.

Examples:

- Total XP 0: Luck 10, 0 / 100 XP
- Total XP 99: Luck 10, 99 / 100 XP
- Total XP 100: Luck 11, 0 / 125 XP
- Total XP 110: Luck 11, 10 / 125 XP
- Total XP 225: Luck 12, 0 / 150 XP

A future, trusted event boundary supports these provisional reward amounts, centralized in `LUCK_EVENT_XP`:

- A verified first discovery of a source: **25 XP**, once for that source
- A legitimate new refill of a previously discovered source: **5 XP**, once for that source and distinct refill-cycle reference
- Opening an empty source: **0 XP**, no receipt, revision change or write

An event reference is not proof that a chest or refill exists. The eventual gameplay owner must establish a real discovered source, genuine newly available loot, and a stable refill-cycle reference from authoritative world state. It must never create fresh event/cycle IDs merely because the user opens a chest again. There is no actual chest refill, loot, cooldown or reward-discovery system added here, and the current bedroom storage chest is not connected to this API. Test fixtures are the only current callers. Before real integration, the gameplay owner's loot/refill evidence and returned stat candidate must be included in a single save transaction.

All positive awards have validated receipts with a historical reward revision. `LUCK_REWARD_REVISION = 1` currently defines exactly 25/5 XP; a future reward-balance change must retain prior revisions or explicitly migrate old receipts. The threshold curve is computed separately; changing it will alter the computed Luck value/progress for existing total XP and requires an intentional balance decision. There is no caller-supplied arbitrary XP amount.

## Persistent state and migration

The permanent local guest file remains `user://bedroom_guest_v1.json`. Save schema **9** uses stat schema **2**:

- `version`: stat schema 2
- `level`: earned character level, bounded positive integer
- `revision`: nonnegative integer incremented on each successful allocation, character-level increase, or positive Luck-XP award
- `allocations`: exactly STR, AGI, VIT, INT and WIS, each a nonnegative integer
- `luck`: exactly `version = 1`, `total_xp`, and `event_receipts`

The separate invariants are:

1. Character free points: `spent_points + unspent_points = 5 × (character_level − 1)`, where spent points sum only the five eligible allocations. Each eligible attribute is `10 + allocation`.
2. Luck: `total_xp = sum(valid earned-event receipt XP)`. Luck value and current/required XP derive solely from this total using the configured curve. Luck does not grant, consume or depend on character free points.

Each positive Luck receipt is keyed by a unique event ID and contains exactly `source_id`, `kind`, `refill_id`, `xp`, and `reward_revision`. A source can have only one first-discovery receipt. A source/refill-cycle pair can have only one refill receipt, and a refill requires that source's first-discovery receipt. IDs must be trimmed, nonempty strings of at most 128 characters. An empty opening never adds a receipt. A safety bound limits receipt count to 20,000, with total XP bounded to that many maximum configured revision-1 awards.

State validation rejects missing/extra fields, unknown keys, malformed receipts, incompatible totals, unknown reward revisions, negative, fractional, nonfinite or boolean numeric values. JSON whole-number floats are accepted because Godot's JSON parser returns numbers as floats. Current v9 saves with missing or invalid stats are rejected without rewriting disk or replacing live state.

The v8 → v9 migration validates the exact old stat schema 1 before changing it. It removes the old LUK allocation, retains all five other allocations and character level, and initializes Luck 10 with zero XP and no receipts. Removing the old LUK allocation refunds exactly those spent points into the derived unspent balance; it never converts them to XP. The stat revision increases once where possible. For example, a level-4 character with 7 points in other stats and 5 in Luck changes from 3 unspent to 8 unspent. Reloading does not repeat the refund; spending the refunded points does not make them reappear.

A v8 file missing its formerly required stats is corruption and does not receive defaults. Unknown extra XP fields in old schema 1 are rejected. If a downgraded backup already contains complete, valid schema-2 Luck XP with reconciled receipts, that genuine supported state is preserved intact. Versions 1–7 without any stat object receive baseline defaults, while valid supplied stat metadata follows the same migration validation. Existing inventory/tutorial migration runs as appropriate. Character identity/class, item instances and provenance, equipment, upgrades, tutorial stage and receipts, gold, shop purchases, and location remain preserved. Migration is validated and written before replacing live state; an I/O failure preserves both the old file and the live session. Schema validation is not cryptographic anti-cheat and cannot prove an edited local file's historical authenticity.

## Save API and menu integration

- `get_stat_summary()` returns detached `ok`, `code`, `message`, `level`, `revision`, `earned_points`, `spent_points`, `unspent_points`, `attributes` (six display keys), `allocations` (five eligible keys), `planned_effects`, and `effects_status`.
- Luck summary fields are `luck_level` (internal rank, not the displayed attribute value), `luck_xp` (current-rank progress), `luck_xp_required`, `luck_total_xp`, and `luck_progress` (fraction in `[0,1)`). Display `attributes.LUK` beside `luck_xp / luck_xp_required` and use the fraction for the XP bar.
- `preview_stat_allocation(deltas, expected_revision)` validates and returns proposed detached values without writes or an exposed candidate state. Only eligible keys are accepted; totals must be positive and within the balance.
- `allocate_stat_points(deltas, expected_revision)` repeats authoritative validation and atomically saves. A stale revision is rejected before mutation. Repeated taps with the same revision cannot allocate twice, including after reload. Unrelated inventory/location changes do not invalidate a still-current stat draft; earned Luck events do change the shared stat revision.
- `advance_character_level(target_level, expected_revision)` remains an unconnected future progression boundary. A future caller must establish the legitimately earned level. It awards exactly five points for each new level and leaves Luck unchanged. The current level returns a no-write no-op; a lower level or stale revision is rejected.
- `record_luck_event(event_id, source_id, kind, refill_id, expected_revision)` is the unconnected trusted future event boundary. Supported kinds are `first_discovery`, `refill`, and `empty_open`; only refill uses a nonempty refill ID. A valid positive event atomically saves its receipt, XP and revision, returning `luck_xp_awarded`. An exact successful replay returns `duplicate = true`, zero award and no write even with the original revision. Reusing that ID for different content is rejected. A new event ID cannot repeat an existing discovery or refill cycle. New events require the current revision. Empty openings return zero and do not write.

Every Save operation requires a valid complete live save. The menu owns its local allocation draft, previews it, and requires explicit confirmation before allocation. Cancelling or switching pages writes nothing. Both failed temporary writes and failed final renames restore the full prior state, including free points, Luck XP, receipts and revision; exact retries can safely succeed. No current UI invokes the level or Luck event APIs.

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

- `tests/character_stats_test.gd`: five-stat accounting, no free-point Luck access, exact Luck thresholds and overflow, separate invariants, refund migration, malformed input/state, event-ID and semantic replay defense, full/reduced/zero rewards, effect ownership and caps.
- `tests/stat_save_test.gd`: every class, allocation/reload, stale/double-tap rejection, both I/O failure stages for allocation and Luck XP, v8 refund persistence and rollback, no duplicate XP after restart, current-schema corruption, older migration preservation, and no Luck XP from existing tutorial/shop/storage actions.
- `tests/stat_panel_test.gd`: local drafts/confirmation, five eligible steppers, Luck value and numeric XP bar with no Luck stepper, partial/threshold progress and UI state restoration.
- Existing tutorial, shop, HUD and inventory regressions ensure their accounting is unchanged.
