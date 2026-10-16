# Adventure Odyssey — Cottage customization roadmap

Updated October 16, 2026. This is an *implementation* checklist, not a claim that all concept-art variants are complete.

## Existing cottage / safe defaults

- [x] Exactly one bedroom, connected foyer and combined living room/kitchen, with Elmwatch return travel.
- [x] Approved cottage background files preserved unmodified.
- [x] Three free starter items remain permanently owned: green oak bed, tall oak mirror and plain wooden storage chest.
- [x] Modular independently drawn furniture sprites on the bedroom background.
- [x] Maintain working bed rest, persistent equipment storage chest and appearance mirror.
- [x] Save-owned and currently equipped furniture; automatically migrate legacy saves.

## Cosmetic furniture shop — implemented

- [x] Open the in-bedroom DECOR panel, also accessible from ROOM STYLE in the chest.
- [x] Three paid Sigil collections: Noble Court (30), Castle Grandeur (60), Royal Legacy (120).
- [x] Each Sigil tier permanently unlocks its Queen / King / Unisex suite containing bed, mirror and chest together (27 transparent illustrations).
- [x] Existing Sigils, owned collections, selected suite and equipped room art persist without changing gold or combat stats.
- [x] Add three individual earned-gold upgrades: Riverside Blue bed (25), Copper Leaf mirror (18), Ironwood chest (20).
- [x] Gold upgrades are purchased only once, remain owned and can be individually equipped or mixed; no Sigils deducted.
- [x] Purchases are gated on real installed art; insufficient balances and invalid slots cannot charge.
- [x] Reserve empty persistent data categories for future cosmetic outfits/accessories without selling unfinished items.
- [x] Include real Godot screenshot and gameplay regression tests in push-only CI; Android APK output remains manual.
- [x] Restore original starter style for free, even after unlocking paid collections.
- [x] Fix shop thumbnail sizing and reflow the mobile-oriented coin, labels and previews.

## Remaining future decor/art work — deliberately not marked complete

- [ ] Visually approve final sizing/alignment of starter and premium furniture against the approved cottage room.
- [ ] Upgrade low-resolution prototype starter textures from the owner's exact approved high-resolution originals when available; do not invent replacements.
- [ ] Integrate remaining individually designed bed, mirror and chest variants from the earlier art pack after asset review (13 bed, 8 mirror, 17 chest planned), without duplicating existing collections.
- [ ] Optional furniture *placement* controls and safe walkability checks (currently fixed original positions).
- [ ] Separate optional floor, wallpaper, lighting and wall decorations, with a layout-compatible save schema.
- [ ] Future cosmetic outfits and accessories with their own approved sprites; no stat advantages or unreviewed billing.
- [ ] Android emulator/device visual and touch tests before building the next signed APK.

See `docs/cottage-decor-collections.md`, `docs/cottage-gold-furnishings.md` and `docs/adventure-odyssey-next-roadmap.md` for integration decisions.
