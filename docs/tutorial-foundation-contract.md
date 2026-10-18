# Tutorial foundation and Save contract

Status: staged source, isolated from the production checkout. These files do not
change the shipped save, inventory catalog, scenes, APK, commit, or remote branch.

## Approved route

1. The player reads an envelope at their home doorstep. Their application is
   approved; it asks them to visit the Adventurer Guild.
2. The receptionist sends the player to the blacksmith.
3. The blacksmith supplies one free +1 upgrade lesson. The player explicitly uses
   the upgrade UI on their existing class-matched starter weapon. There is no
   second weapon grant. The eligible weapon can be in the chest, bag, or equipped;
   the Save owner preserves that instance's owner, binding, and container.
4. The player returns to the receptionist and receives the apothecary errand.
5. The apothecary gives exactly five mana potions, then the player returns.
6. The receptionist sends the player to the general store for a keepsake ring.
7. The shopkeeper says, “I've been holding this until you were ready.” If asked
   who left it, the reply is, “I'll let them tell you that.” Asking the question
   does not claim the ring or advance the quest.
8. After the final receptionist return, the first combat assignment is pending.
   The tutorial remains incomplete until a real combat system can verify it.

The absent high-ranking adventurer mother is hidden authoring context only. No
current dialogue, quest objective, button, or reward label reveals that connection.

The original starter package remains the chest's five healing potions and
class-matched starter weapon, worn starter armor, plus the separately approved
100 character gold. The quest planner does not reseed those items or gold.

## Owned files

- `src/tutorial_progress.gd`: deterministic, pure transition and reward planner
- `src/tutorial_dialogue.gd`: read-only ornate dialogue component
- `tests/tutorial_flow_test.gd`: model and dialogue regression suite
- This contract

The model references the existing `Inventory.starter_weapon(class)` mapping. The
UI references `src/ui/ornate_panel.gd` and the existing body font. Neither file
creates a save, edits inventory, consumes currency, applies upgrades, or performs
combat.

## State schema

`Progress.initial_state()` returns a fresh dictionary:

```json
{
  "version": 1,
  "stage": "awaiting_letter",
  "action_receipts": {},
  "event_receipts": {},
  "reward_receipts": {}
}
```

`Progress.validate_state(value)` accepts only the complete, internally consistent
schema. It validates the exact completed prefix of the route, receipt uniqueness,
receipt from/to stages, required reward receipts, and the absence of extra
receipts/fields. It accepts integral JSON numbers after a save round trip. It does
not silently reset invalid or unknown-version state, and it never overwrites it.

Action/event receipt maps use semantic IDs as keys. Values are:

```json
{"id":"owner-generated-request-id", "from":"awaiting_letter", "to":"visit_guild"}
```

Reward receipt maps use the stable reward ID as key. Values are:

```json
{"id":"owner-generated-request-id", "owner":"apothecary_claim_gift"}
```

The transport request ID is a nonblank, trimmed string of at most 128 characters.
It cannot be reused for another semantic operation. Repeating a completed action
with the same or a fresh request ID is an accepted no-op with no new rewards and
the latest state. Late retries never rewind the route.

## Planner API

```gdscript
Progress.plan_action(state, action_id, receipt_id, context = {})
Progress.plan_event(state, event_id, receipt_id, context = {})
Progress.objective(state)
```

Both planning methods return:

```gdscript
{
    "ok": true,
    "duplicate": false,
    "code": "ready",
    "message": "",
    "next_state": candidate_state,
    "rewards": reward_manifests
}
```

The caller's state and context are not mutated. The returned state is a deep copy.
Failure and duplicate results include no rewards. A successful plan is not proof
of persistence; receipts in `next_state` are merely part of the proposed atomic
transaction until Save commits it.

| Current stage | Operation | Next stage |
| --- | --- | --- |
| awaiting_letter | action `read_envelope` | visit_guild |
| visit_guild | action `guild_assign_blacksmith` | visit_blacksmith |
| visit_blacksmith | action `blacksmith_claim_starter` | upgrade_blacksmith |
| upgrade_blacksmith | event `blacksmith_upgrade_applied` | return_guild_blacksmith |
| return_guild_blacksmith | action `guild_after_blacksmith` | visit_apothecary |
| visit_apothecary | action `apothecary_claim_gift` | return_guild_apothecary |
| return_guild_apothecary | action `guild_after_apothecary` | visit_general_store |
| visit_general_store | action `general_store_claim_keepsake` | return_guild_general_store |
| return_guild_general_store | action `guild_after_general_store` | first_combat_pending |

`blacksmith_claim_starter` is the stable historical action name for accepting
supplies; it grants **no starter weapon**. It requires trusted
`context.character_class`, using the catalog's exact class label. Other action
contexts are ignored.

The upgrade event requires trusted, Save-derived context:

```gdscript
{
    "character_class": "Warrior",
    "item_id": "warrior_01_weapon",
    "from_level": 0,
    "to_level": 1,
    "supplies_consumed": true
}
```

The planner checks those fields but is **not a security boundary**. The Save
integration must create that event only after validating the actual owned starter
instance and consuming the one-use entitlement in the same transaction. UI code
must never submit arbitrary event contexts. Invoking an event ID through
`plan_action` fails.

`first_combat_completed` always returns `combat_unavailable`, including when a
caller supplies fake victory or verified flags. There is no `complete` stage in
this foundation. A future combat integration must explicitly extend this schema
and tests with a real, idempotently persisted combat outcome. Do not expose a
debug, dialogue, timer, or fake victory path to completion.

## Reward manifests

The blacksmith returns only this entitlement:

```gdscript
{
    "receipt_id": "tutorial.blacksmith.upgrade_supplies",
    "kind": "upgrade_entitlement",
    "entitlement_id": "tutorial_weapon_plus_one",
    "uses": 1,
    "target_item_id": Inventory.starter_weapon(character_class),
    "target_level": 1,
    "binding": "character",
    "source": "tutorial"
}
```

This encodes the supplied free lesson without inventing material item IDs,
ingredient quantities, prices, success probabilities, or damage/stat formulas.
The actual +1 metadata change happens only when the player confirms the upgrade
UI. The existing eligible weapon's stable instance ID should be recorded by Save
when selecting the target so a similarly named earned item cannot be substituted.

Apothecary and general store return item grants:

```gdscript
{
    "receipt_id": "tutorial.apothecary.mana_potions",
    "kind": "item", "item_id": "mana_potion", "count": 5,
    "binding": "character", "source": "tutorial"
}
{
    "receipt_id": "tutorial.general_store.keepsake_ring",
    "kind": "item", "item_id": "keepsake_ring", "count": 1,
    "binding": "character", "source": "tutorial"
}
```

Save/catalog integration must register those item identities before applying a
grant. An unknown, malformed, unsupported, or unpersistable reward fails the
whole transaction. No restoration amount or ring statistics are defined here.

Binding policy: starter armor/weapon, tutorial potions/ring, and NPC purchases
belong to one character. Character gold cannot transfer. Earned loot remains
transferable. Ownership/binding comes from instance provenance, not merely an
item ID, so a legitimate earned item is not accidentally bound by matching a
tutorial catalog identity.

## Save-owned transaction API

Recommended public entrypoints are intentionally narrow:

```gdscript
Save.perform_tutorial_action(action_id: String) -> Dictionary
Save.apply_tutorial_weapon_upgrade() -> Dictionary
```

The Save owner may retain explicit `tutorial_action(action_id, receipt_id)` /
`apply_tutorial_weapon_upgrade(receipt_id)` wrappers if integration requires them;
the receipt is only an idempotency key, never authority for rewards or context.
Prefer generating stable receipt IDs inside Save and never accepting caller
inventory, class, currency, reward, binding, or completion claims.

For a new action:

1. Validate the loaded save, current character identity, tutorial state, scene/NPC
   eligibility, and actual instance ownership. Check duplicates before scene
   eligibility so safe retries after travel remain accepted no-ops.
2. Build the trusted context from the loaded character and inventory. Plan the
   requested action; reject invalid stage/action/reward manifests.
3. Copy the complete save candidate, including inventory instances, equipment,
   entitlements, character wallet, and all receipts. Apply approved rewards and
   the candidate tutorial state to that copy. Validate all limits and invariants.
4. For the upgrade UI action, find the original character-bound class starter
   weapon in chest/bag/equipment. Require level 0 and the matching unconsumed
   entitlement. Upgrade that instance to +1 and consume the entitlement, then
   plan `blacksmith_upgrade_applied` with the actual before/after data. Persist all
   three changes together. Never emit that event merely for opening the UI.
5. Write one full replacement save through the project's atomic temporary-file
   path. On any validation/write/rename failure, preserve the previous disk save
   and all authoritative live state. Return a readable retryable error.
6. Only after successful persistence publish the candidate state/inventory to the
   session and return success. A duplicate returns success without changing the
   save or creating a reward again.

Do not save the receipt separately before or after the reward. A crash between
those writes would either lose the gift or duplicate it. Grant claims are not
proof that the player still owns a consumed potion; replay safety relies on the
receipt, not on current inventory counts.

The Save integration's suite must exercise real create/migration/load round trips,
write failure rollback, upgrades from chest/bag/equipped containers, instance
ownership, all six classes, and duplicate retries after a restart. Those are
integration requirements, not claims made by the pure model's tests.

## Dialogue integration

```gdscript
dialogue.configure(npc_id, save.tutorial, save.character["class"])
dialogue.action_requested.connect(on_tutorial_action)
dialogue.service_requested.connect(on_service_request)
dialogue.dismissed.connect(close_dialogue)
```

NPC IDs: `envelope`, `guild_receptionist`, `blacksmith`, `apothecary`, `shopkeeper`.
Service IDs: `tutorial_upgrade`, `blacksmith_shop`, `apothecary_shop`,
`general_store_shop`. Service signals carry only an intent to open a service.

`configure` copies the state, clears pending/error state, and re-renders. Action
and service buttons become pending before signal emission to prevent duplicate
clicks. `show_error(message)` shows an owner-side failure and enables retry.
`set_pending(false)` also enables retry when returning from a service without an
action. `dismissed` fires once per configured view. Leave, Escape, and Android
Back stay usable while a transaction is resolving; closing does not cancel a
committed save or grant rewards. Controllers must check the view is still valid
before refreshing it after an asynchronous save completes.

The panel uses the existing light ivory/gold ornate background, ink text,
touch-sized controls, a scrollable conversation body, and an always-visible Leave
button. It does not move the player, pause the scene, or own modal input routing;
the scene controller retains those responsibilities.

## Verification

Verified with Godot 4.6.3 in an isolated harness containing exact copies of these
three staged source/test files plus existing catalog, panel, and font dependencies:

- Clean headless editor import after setting writable XDG config/cache/data
- `godot --headless --path <harness> --script res://tests/tutorial_flow_test.gd`
- 870 checks; 0 failures
- Six-class route, deterministic plans, immutable inputs, exact gift quantities,
  no extra weapon, idempotency, request conflicts, corrupted progress, forged
  upgrade/combat rejection, JSON round trips, every offered dialogue action,
  secret-free public text, repeated pending/close/retry behavior, and geometric
  layout checks at 1280×720, 960×540, and 640×360

The suite also supports `-- --capture` under a working native display, writing
`tutorial-dialogue.png` in its project/harness root. Native pixel capture was not
verified in this executor: `xvfb-run` is absent; the installed dummy X server
could not create its local sockets; the supported escalation path failed before
the process launched. Do not treat geometry-only checks as visual approval.

No full-game integration, Android device testing, combat, economy/balance, APK
build, commit, push, or production modification is included in this deliverable.
