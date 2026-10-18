# Bounded NPC shops and save accounting

## Scope and current development policy

The Apothecary sells Healing potion and Mana potion. The General Store sells Healing potion. Each costs **10 gold per item**, a provisional development price approved for this bounded feature because the historical asset/design audit found no approved price table. The source of truth is `src/shop_catalog.gd`, not UI text or a caller-supplied price.

Stock is explicitly **unlimited**. There are no stock decrements or restock timers. Each transaction accepts a whole quantity from 1 through 10. The per-item bag cap remains 999. This feature adds no gear sales, selling, refunds, earning, restocking, potion consumption/effects, combat math, or item-stat formulas. Tutorial gifts still use their separate one-time receipts.

The current game has a finite **100-gold lifetime pool**, seeded in the bedroom chest once. The player must claim it into their wallet before buying. Purchases cannot spend chest gold, reseed gold, or infer income. The maximum spend of 100 and maximum of 100 purchase receipts are deliberate bounds for this scaffold. Future income/refunds require an explicit source-of-funds ledger and corresponding conservation/migration tests before increasing these bounds.

## API contract

`save.get_shop_catalog()` returns the currently accessible shop, derived from the saved interior scene and proximity to that merchant's authored NPC interaction anchor. It requires a valid save and a distance at most 90 logical pixels. A scene name alone is insufficient; the bedroom, guild, and blacksmith do not expose shops.

Success returns:

- `ok: true`, `code: "shop_available"`, `message: ""`
- `shop_id`: `apothecary` or `general_store`
- `shop_name`, `stock_policy: "unlimited"`, `max_quantity: 10`, `wallet_gold`
- `offers`: detached dictionaries containing `item_id`, `label`, and `unit_price_gold`

`save.purchase_shop_item(item_id, quantity, transaction_id)` takes no shop, price, discount, owner, grant, binding, or receipt supplied by the caller. It validates primitive input types and bounds, derives the shop again from the persisted NPC proximity, looks up the current authoritative price, and checks wallet funds and bag capacity.

Transaction IDs are nonblank, trimmed strings up to 96 characters. The UI generates an ID for a purchase intent and retains it when retrying a failed save. Cancelling/revising an intent or explicitly starting another purchase must use a fresh ID. An identical successful request at the same shop returns its existing receipt without writing the file, taking gold, or granting anything again. This remains true after reload, with zero gold, or with a full bag. Reusing an ID with another item, quantity, or shop is refused. Retry validation still requires being at the saved merchant location; walking away cannot authorize a new transaction.

A successful result contains `ok: true`, `duplicate`, `code: "purchased"` or `"already_purchased"`, `message`, and a detached `receipt`:

- `transaction_id`, `character_id`, `shop_id`, `item_id`
- `quantity`, `unit_price_gold`, `total_price_gold`, `catalog_revision`

A failure returns `ok: false`, `duplicate: false`, `code`, `message`, and an empty `receipt`. Error codes:

| Code | Meaning |
| --- | --- |
| `invalid_save` | No valid character or internally invalid live save |
| `wrong_location` | Not at a supported merchant's saved interaction anchor |
| `invalid_item` | Invalid item type or item unavailable at this shop |
| `invalid_quantity` | Non-numeric, non-finite, fractional, boolean, or outside 1–10 |
| `invalid_transaction_id` | Invalid type, empty/whitespace, surrounding whitespace, or more than 96 characters |
| `transaction_conflict` | ID already belongs to a different purchase or an existing acquisition |
| `insufficient_gold` | Wallet cannot cover the complete authoritative total |
| `inventory_full` | Complete quantity would exceed the item's bag cap |
| `save_failed` | Atomic persistence failed; all live mutations were restored |

Pure catalog helpers are `entries_for(shop_id)`, `shop_name(shop_id)`, `scene_for(shop_id)`, `shop_for_scene(scene)`, and `unit_price(shop_id, item_id, revision)`. They do not authorize a purchase. Displayed offer and returned receipt dictionaries are detached copies.

## Atomic transaction and provenance

One successful save contains all of the following changes together:

1. The wallet is debited by the catalog price times the requested quantity.
2. A `purchase_receipts[transaction_id]` entry records the authoritative transaction.
3. An `acquisition_receipts["shop:" + transaction_id]` entry records the item, quantity, and `npc_purchase` provenance.
4. A new inventory ledger stack grants that quantity to the bag, owned by the character and character-bound under the existing provenance policy.
5. Compatibility inventory counts are synchronized from the ledger.

The existing temporary-file/rename transaction writes the complete snapshot. A failed temporary write or failed final rename restores wallet, ledger, compatibility views, both receipt maps, tutorial data, location, and all other saved fields. The previous disk file remains unchanged. The ID remains available for a subsequent retry. Moving purchased stacks between bag/chest preserves their source receipt, identity rules, owner, and character binding; another character cannot receive them.

The old `receive_item` method is retained as a **trusted compatibility acquisition hook** for existing gameplay/provenance fixtures and future internal acquisition systems. Existing tests and old saves can contain `npc_purchase` provenance grants without paid receipts. That method does not execute a purchase or debit gold and is not exposed to the shop UI. Such historical grants never count as evidence of spending. New shop UI paths must use `purchase_shop_item` exclusively.

## Save v7 and migration

The permanent slot path remains `user://bedroom_guest_v1.json`. Save v7 adds `purchase_receipts`; v6 identity, inventory ledger, acquisition receipts, ownership, tutorial receipts, equipment, location, and gold are preserved. A v6 migration adds an empty paid-receipt map and no items or currency. The original v1–v5 migrations remain supported. Migration writes and validates its candidate before replacing live state. If writing fails, the previous live state and original file are retained.

Gold conservation is now:

`chest_gold + wallet_gold + verified_paid_total == 100`

Every paid receipt must have exactly the expected fields, match its dictionary key and character, contain valid finite whole numeric values, name an approved historical shop/item/price revision, satisfy `quantity × unit_price == total`, and match the `npc_purchase` acquisition. Existing ledger validation independently verifies the acquisition's total grant quantity, owner, binding, and compatibility counts. A fabricated discount, omitted grant, missing debit receipt, changed owner, unknown revision, duplicate identity, or restored spent gold is rejected. A v7 file missing the new map is malformed; it is not silently migrated as a new slot. Downgrading a spent save and removing its paid accounting cannot reseed its currency.

Catalog revision 1 holds the current provisional prices in `PRICE_HISTORY`. To change future prices, add a new revision and update `CURRENT_REVISION`; retain old revisions so valid old receipts continue to load. Editing a historical price would invalidate existing purchases and must not be used for a rebalance.

These checks establish local structural/accounting consistency. They are not cryptographic authentication or a multiplayer anti-cheat boundary: a person who can replace the executable and all internally consistent save evidence controls their local game. The UI cannot submit a receipt or price to the purchase API.

## QA

Run with a writable Godot user-data location in a sandbox:

```sh
XDG_DATA_HOME=/tmp/ao-shop-qa/data \
XDG_CACHE_HOME=/tmp/ao-shop-qa/cache \
XDG_CONFIG_HOME=/tmp/ao-shop-qa/config \
godot --headless --path . --script tests/shop_save_test.gd
```

The focused service suite covers supported catalogs and immutable displays; unsupported scenes, distant merchants, and boundary proximity; zero wallet and unclaimed chest gold; malformed input types and numeric bounds; cross-shop stock validation; exact debit and bound grants; double taps and retries after reload at zero balance; conflicting and distinct IDs; complete-spend and no-reseed behavior; capacity; split-stack storage; temporary-write and final-rename failure rollback; v6 migration success/idempotency/I/O failure; retained historical NPC grants; purchase receipt, price, quantity, owner, catalog, currency, and missing-grant corruption. Existing tutorial, inventory, and migration regressions must also remain green.
