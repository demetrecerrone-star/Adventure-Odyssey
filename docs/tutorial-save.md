# Tutorial save transaction contract (version 6)

The permanent guest slot is still `user://bedroom_guest_v1.json`. This change does not introduce accounts, networking, a trade system, combat, item effects, prices, or a new save slot. The existing appearance, class weapon equipment, inventory transfer, and location APIs retain their signatures. The tutorial ends at `first_combat_pending`.

## Public integration API

- `perform_tutorial_action(action: String) -> Dictionary`: accepts only a semantic action, derives the class, generates an internal character-specific receipt, validates stage and proximity, and commits planner state and rewards together. Results include `ok`, `duplicate`, `code`, and `message` (plus the pure planner's detached `next_state` and `rewards`). There is no entrypoint accepting a submitted plan, reward manifest, event evidence, or tutorial receipt.
- `apply_tutorial_weapon_upgrade() -> Dictionary`: locates the existing starter-provenance class weapon; requires it to be carried in the bag or equipped (a weapon left in the bedroom chest is refused with a collection prompt); consumes the blacksmith entitlement and changes that same instance's `upgrade_level` from 0 to 1; commits the verified event with those changes. It never creates another weapon. No damage, stats, price, material recipe, or combat effect is inferred.
- `tutorial`: validated pure quest state. The quest model and dialogue never write the save.
- `chest_gold`, `wallet_gold`; `claim_chest_gold() -> bool`: moves the remaining 100 starting gold from the bedroom chest to that character's wallet. Gold is not an inventory item and has no deposit, trade, or cross-character transfer API. The bounded implementation conserves exactly 100 gold until a future explicitly designed economy is added.
- `equipped_ring`, `equip_ring(item = "keepsake_ring")`, `unequip_ring()`: separate accessory slot; no invented stat bonus. Existing `equip()` / `unequip()` still control weapons only.
- `get_item_instances(item_id = "", container = "") -> Array`: detached per-stack metadata, including mixed sources of the same item type.
- `get_item_details(item_id, container = "bag") -> Dictionary`: detached selected-instance metadata plus `instance_id` and a label containing `+1` when appropriate. Returns `{}` when absent; does not crash on legacy view-only UI test fixtures. Selection prioritizes the upgraded instance.
- `weapon_upgrade_level(container = "equipped_weapon") -> int`: metadata-only inspection.
- `can_transfer_instance(instance_id, recipient_character_id) -> bool`: a bound instance permits only its owning character. An unbound instance may transfer to another named character. This is a predicate, not an implemented transfer/trade operation.
- `snapshot() -> Dictionary`: a complete deep copy for testing and inspection. JSON round-trip it before comparing to a parsed save, because Godot dictionary equality distinguishes nested integer and float variants.
- `receive_item(item_id, quantity, source, acquisition_id) -> bool`: a trusted **future gameplay-system** acquisition recording boundary, not a shop or reward claim UI. Allowed sources are `world_drop`, `trade`, and `npc_purchase`. The first two remain unbound; NPC purchases bind to this character. Repeating the same acquisition ID and payload is an idempotent success; changing its item/count/source fails. Tutorial and starter sources cannot be supplied through this API. It performs no purchase, price calculation, debit, random drop generation, or external communication.

Scene interactions first persist the actual player position with `set_location`, and invoke the Save API only after that write succeeds. Save independently requires the proper scene and a position within 90 pixels of the shipped layout's NPC interaction anchor. The doorstep envelope uses world position `(1708, 1340)` and the same radius. Completed semantic actions can be harmlessly retried from any location; they return an empty reward list without writing. The prior completed action's original receipt stays unchanged.

## Version 6 data

The count dictionaries `bag` and `chest` still contain a count for every catalog item. `equipped_weapon`, `equipped_armor`, and `equipped_ring` remain item-ID strings for existing rendering/UI consumers. They are validated compatibility **views**, not provenance or grant authority. Direct edits are not persisted as new loot; gameplay must use the mutation APIs. UI-only fixture construction still works for display.

`character_id` is a random 128-bit stable identity, independent of username, appearance, and class-label text. New saves and legacy migration create it once. All records keep `owner_id` equal to that identity.

`item_ledger` contains stacks/instances with exactly these fields:

| Field | Meaning |
| --- | --- |
| `id` | Stable random instance/stack ID |
| `item_id` | Catalog item type |
| `quantity` | Positive whole count, bounded at 999 |
| `container` | `bag`, `chest`, `equipped_weapon`, `equipped_armor`, or `equipped_ring` |
| `owner_id` | Stable character ID |
| `binding` | `character` or `unbound` |
| `source` | `starter`, a specific tutorial reward ID, `npc_purchase`, `world_drop`, `trade`, or `legacy_unattributed` |
| `source_id` | Immutable starter/reward/acquisition provenance identifier |
| `upgrade_level` | 0, or the verified starter lesson's 1 |

Moving a whole instance preserves its ID and every provenance field. Splitting one unit off a consumable stack creates a distinct stack ID and preserves owner, source, and binding. Equipment moves the actual instance. Neither `LABELS` nor the item type globally implies binding: the same healing-potion or class-weapon type can coexist in bound and unbound stacks. All starter armor/weapon/free healing potions, tutorial gifts, and NPC-purchase records are character-bound.

`upgrade_entitlements` retains the blacksmith receipt with owner, target item, target level, and remaining uses (1 before applying the lesson, 0 afterward). `acquisition_receipts` preserves accepted future gameplay acquisition IDs and payloads across reload. `tutorial` uses the separate pure model's version-1 stage/action/event/reward schema; it cannot contain arbitrary extra progression fields.

Validation checks quantities, equipment slots, all projection counts, unique instance IDs, owners, provenance and binding consistency, exact tutorial gift totals, receipts tied to the stable character, entitlement availability/consumption, and correspondence between the upgrade event and the actual existing upgraded starter instance. Invalid, partial, or inconsistent data is rejected before any live replacement or file write.

## New characters and migrations

A new character has 100 gold in the chest, five bound healing potions, one bound class starter weapon in the chest, and the existing class armor equipped and bound. No extra starter weapon comes from the smith. The apothecary gives five bound mana potions once; the general store gives one bound keepsake ring once.

Versions 1–5 load through a candidate-only migration:

- v1 preserves the existing project's retirement rule for its unreleased sample bread/keepsake inventory: replace it with five healing potions and the class starter weapon.
- v2 preserves exact healing-potion bag/chest counts and adds the class weapon only if it was not already equipped.
- v3–v5 preserve every supported inventory count, equipped weapon, class armor, appearance, and valid location. New catalog count keys default to zero. No class weapon is silently recreated if the older save is missing it; the smith reports that absence rather than issuing another weapon.
- At most one existing own-class weapon (equipped first, then bag/chest) and five existing healing potions are attributed to the old starter grant. The known starter armor remains bound. Extra loot remains `legacy_unattributed` and unbound rather than inventing provenance or globally binding an item type.
- Since these builds predate currency, migration seeds the approved 100 gold in the chest once. If an explicit valid `gold_seeded` marker and corresponding wallet/chest balances already exist, they are preserved. Complete modern metadata in a version-downgraded backup is validated and retained; partial modern metadata is rejected, so it cannot accidentally reset rewards or identity.
- The old wake gate becomes `awake: true`; no loot is refilled. Successful migration writes v6 before installing it into the current session. Subsequent loads do not migrate or reseed.

## Transaction and trust boundary

Every mutating API captures a complete deep snapshot, validates the candidate, writes JSON to the same-directory `.tmp`, flushes and closes it, then atomically renames it over the slot. Failure restores all in-memory fields and preserves the previous destination bytes. Migration validates and writes an isolated candidate before replacing the live session. A failed load never replaces the live character. Errors are retained for presentation; they are not saved game state.

Tutorial receipts are generated inside Save from character identity and semantic action. Reward manifests come only from the pure planner and are allowlisted again when applied. Replays cannot add gifts, reuse smith supplies, forge a combat completion, or use an unrelated same-type weapon as the original lesson target.

This is an offline local save, not a cryptographic anti-cheat system. It rejects invalid and inconsistent receipts/provenance, but cannot prove historical authenticity against someone deliberately rewriting an entire mutually consistent JSON file or executing arbitrary game code. The pure planner is likewise not a persistence authority. Future real consumption, economy, trade, or combat systems must extend the ledger/receipt reconciliation explicitly; they must not mutate count dictionaries or fabricate tutorial events.

## Verification

`godot --headless --path . --script tests/tutorial_save_test.gd` exercises real temporary local files, all six classes and both bases, every initial starter-weapon container including refusing a weapon left in the home chest, the complete sequence with reload after each step, duplicate actions, rollback at every tutorial stage and all regular mutations, mixed provenance, accessory slots, invalid ownership/receipt/ledger data, overflow, and v1–v5 migration with write failure and repeated loads. It uses isolated temporary slot names and removes them afterward.

Also run existing bedroom, interior-save, interior-routing, appearance, adventure-menu, HUD, and HUD-integration regressions. Use isolated `HOME` / XDG directories when the machine's ordinary Godot user directory is not writable; never test against the user's actual guest slot.
