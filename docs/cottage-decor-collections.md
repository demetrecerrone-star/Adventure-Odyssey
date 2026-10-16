# Cottage Decor Collections — in-game asset integration

Each icon is ONE whole-tier purchase. **30 Sigils** unlocks the Noble Court tier, **60 Sigils** unlocks Castle Grandeur, and **120 Sigils** unlocks Royal Legacy. Every tier purchase permanently unlocks the Queen's Chamber (feminine), King's Hall (masculine), and Royal Harmony (unisex) suites, each containing its own bed, mirror and storage chest illustrations. No gender/class restriction applies.

## Current game implementation
- Original starter oak-green bed, oak mirror and plain chest remain unchanged, fully functional and free. Starter is always owned.
- Tap the AO coin **DECOR** button while in the bedroom, or use ROOM STYLE from the storage chest.
- One BUY button per price tier. Once purchased, BUY changes to EQUIP; active tier indicates EQUIPPED.
- Inside each owned tier, pick QUEEN / KING / UNISEX freely, and use EQUIP THIS STYLE. No repeated payment, no extra currency costs.
- All 27 original-made SVG transparent illustrated sprites are stored individually under `assets/home/collections/<tier>/<style>/<object>.svg`. Beds, mirrors and chests are independent textures in the actual playable bedroom, not screenshots or fake preview placeholders.
- Preview images in the menu are loaded from the same files the furniture uses in the room.
- The existing `home_styles` and `home_owned` save dictionaries remain compatible. `cottage_tiers_owned`, `cottage_active_tier` and `cottage_style_choices` store the purchase and selected style.
- Sigils stay entirely separate from gold. The first Guardian's Legacy quest rewards 30 Sigils once as agreed; normal enemies grant none, and Guardian fights retain their distinct rare 5-Sigil roll.
- Gate all purchases on actual art availability. If any of the nine images for a paid tier is missing, that tier stays ART PENDING and cannot charge currency.

## Further visual art review
The new vector sprites are actual separate transparent illustrations for this integration pass, closely modeled on the native small ornamental furniture silhouettes. They should be visually reviewed against the approved starter furniture in the Godot screenshots and polished if necessary. The starter originals remain untouched.

## Testing and Android
`tests/cottage_collections_test.gd` checks all three tier prices, actual per-object textures, free style switching, purchase ownership, anti-double-spend, persistence, town guards and functional starters. GitHub push workflow runs tests without exporting an APK. Android exports remain manual only.
