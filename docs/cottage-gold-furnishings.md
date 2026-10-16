# Adventure Odyssey — Gold Furniture Extension (2026-10-16)

This is an **additive** upgrade to the existing, validated three Sigil collection tiers. The previous Noble/Castle/Royal SVGs, free starter oak set, approved cottage backgrounds, existing Sigils balance, and original AO app icon have not been changed.

## Everyday gold furnishings

| Furniture | New style | Gold, once |
| --- | --- | ---: |
| Bed | Riverside Blue | 25 |
| Mirror | Copper Leaf | 18 |
| Storage chest | Ironwood | 20 |

All three are newly authored transparent crisp-edge SVGs, installed **beside** the existing free PNG sprites. Each object has its own persistent `home_owned` purchase state and `home_styles` equipped state. Equipping an owned item never charges again. Paid Sigil collection suites continue to equip matching bed/mirror/chest trios together and can override a mixed gold room whenever desired. Buying gold furniture does not use Sigils; buying Sigil suites does not use gold. Missing or invalid artwork can never charge either currency.

Open from **Bedroom > DECOR > GOLD FURNITURE**. You can still enter the original paid suite store. `cottage_active_tier=custom` is now a recognized save state. Existing character saves default safely to free starter pieces; the new `cosmetic_owned` / `cosmetic_equipped` dictionaries reserve empty outfit/accessory categories for future art-approved **non-stat** cosmetics, without selling unfinished products.

## Validation and actual in-game image review

`tests/cottage_gold_shop_test.gd` checks ownership, gold deductions, missing funds, no double charge, exact live Godot sprite resources, save/load and room re-creation, future category save fields and out-of-home restrictions. Existing Sigil and collection tests are retained.

`tests/cottage_shop_screenshot.gd` captures live rendered Godot images (not illustration mockups): free starter, Noble Queen, Castle King, Royal Unisex, mixed gold furnishings, the gold shop, and Sigil shop. The push-only validation workflow includes all those PNGs in its screenshot artifact and **never exports an Android APK**.

## Art review

The new gold items are first-pass crisp-edge hand-authored pixel-vector art. Review the screenshots for size, silhouette, and matching the cottage background before locking the production art.
