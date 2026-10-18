# Inventory character and item-icon checkpoint

Inventory reuses the approved ivory/parchment/gold menu shell and presents the actual saved layered character beside a separately scrollable owned-item list. The preview uses the saved base, class, hair, skin, eyes and currently equipped weapon. Scrolling or inspecting an item never changes equipment or moves the portrait. Explicit Equip/Unequip still invokes the existing authoritative scene/save handlers. No new inventory or progression schema is introduced.

Bag rows show actual counts, names and item-specific icons. Tapping an item reveals its details and a Back to bag button; class restrictions, ownership/binding and undefined numerical bonuses remain explicit. Worn armor, equipped weapon and ring appear in the equipment section; no absent item is shown as owned. Empty bags remain supported.

`inventory_item_icon.gd` draws unchanged isolated gear atlas regions for the six actual class weapons and six starter outfits. It does not modify the character art or source textures. Bottle and ring UI illustrations are purpose-drawn native primitives; healing and mana use distinct red/blue fills. They are illustrative UI icons, not new world items or functional potion effects. Gear rendering is cached per base/item. Unknown icons are marked unavailable instead of inventing an item.

`inventory_panel_test.gd` checks catalog coverage, actual saved appearance, count/ownership, class restrictions, viewport geometry, fixed portrait during list scrolling, read-only inspection and returning to the bag. `inventory_screenshot.gd` renders 13 actual native desktop/phone/handedness states and a 15-item icon sheet. Its fixture only transfers existing starter items; inspection does not equip, and the capture explicitly clicks Equip to verify the real saved avatar update.

No APK is built for this QA-only checkpoint. Native CI screenshots must be inspected before completion. Hardware Android touch/performance remains a separate test.
