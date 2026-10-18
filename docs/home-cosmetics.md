# Home cosmetics: first earned-Sigil selection

A bounded appearance-only catalog: Moonweave and Emberweave armor dyes (3 Adventure Odyssey Sigils each), Riverside and Rose dusk blankets (4 each). Prices are provisional tuning constants in `cosmetic_catalog.gd`, not real-money prices. Original class colors and the green oak bed remain free. Chest and mirror interactions are unchanged; reach Dyes & decor from the bed or storage chest.

The catalog adds no armor, statistics, inventory stacks, damage, or probability modifiers. Armor pigments apply only to the existing independent armor Sprite2D. Body/skin/eyes, hair, and held weapons keep their own materials. The cosmetic selection remains independent when gear or animation frames change. Neutral highlights and metal accents retain their original values. Blanket pigment is isolated by original registered UV bounds and olive hue; oak frame, pillow, alpha, furniture collisions and interaction anchors remain unchanged.

## Art provenance

All underlying images are the approved source artwork already present in this repository. No raster artwork was generated or altered for this selection. Two reversible runtime shader palettes provide each variant. The archived alternate furniture SVGs were inspected and excluded because their older pixel-art style is incompatible with the current painted room. Different mirror/chest shapes remain future content, not hidden upgrades in this build.

## Save contract

`wallet_sigils`, `cosmetics.owned`, `cosmetics.equipped` are owned by the save/economy layer. Catalog defaults: `armor_dye: armor_original`, `bed: bed_oak_green`. The UI previews without touching saved state, asks for explicit purchase confirmation, calls atomic `purchase_cosmetic(id)`, then offers a separate free `equip_cosmetic(id)`. Closing a preview keeps the equipped appearance. Failed writes must preserve the full prior wallet/ownership/equipment; repeated purchases must not charge again. There is no resale/refund economy. Failed-transaction rollback is mandatory. Runtime scenery materials update only after successful saved equipment changes.

## Verification

- Content test: 1,957 checks across both bases, all six classes, every direction and six-frame walk cycle. Checks separate body/weapon materials, default restoration, and preservation across avatar reconfiguration.
- Existing bedroom regression: 334 checks passed. UI confirmation and canceled-touch handling: 14 checks passed.
- All twelve class/base combinations reviewed natively in original, blue and rose palettes.
- Native 844×390 preview: all six choices and explicit buy confirmation rendered and inspected. Original oak/pillow stay unchanged, dye previews are legible, purchase and close controls fit the phone viewport.
- Real-wallet integration: 552 checks across all six classes passed against save v11. Tests earn seven Sigils through verified encounter records, then exercise preview, atomic failed purchase/equip, duplicate purchase, wallet exhaustion, saved ownership/reload, free defaults, unchanged stats/gold/gear, and functional chest/mirror.
- Thirteen native views use the real earned wallet, including explicit confirmation, equipped selections, insufficient funds, both handed home layouts and reloaded room appearance. All reviewed; three additional all-class palette grids cover 12 character/base combinations.
- Device performance on Android has not been measured in this milestone. No APK was requested or produced.

Future price changes must update receipt validation/migration deliberately; existing saved purchases must retain their historical paid price. The current catalog and save validator intentionally agree on the initial price schedule.
