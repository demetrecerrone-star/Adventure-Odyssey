# Bounded shop-service checkpoint

The existing apothecary sells healing and mana potions; the general store sells healing potions. These are the existing catalog items. Prices are provisional development values (10 gold each), not approved final balance. Stock is explicitly unlimited. No paid equipment, resale, paid smith progression, potion restoration amounts, combat effects, or restock clock is implied.

The scene opens a read-only catalog from the actual saved counter location. Selecting an item and quantity leads to a separate confirmation view. Only confirmation calls the Save-owned purchase transaction. Success refreshes the actual wallet and bag; failure keeps the same intent retryable. Returning to the attendant does not spend anything. Shop items use existing character-bound NPC acquisition semantics.

Source coverage includes scene entry, browsing/back without mutation, held-input blocking, actual insufficient/failed-save behavior, retry, reload and exact gold/item totals. Native CI captures both shops at desktop and phone landscape sizes, including confirmation and purchase results. Android hardware touch/performance remains unverified until an explicitly requested APK checkpoint.

Combined local verification: 25 suites plus title, 40,573 checks with zero failures. This includes shop-save357, shop-panel103 and shop-scene22. Native UI rendering remains the publication gate.
