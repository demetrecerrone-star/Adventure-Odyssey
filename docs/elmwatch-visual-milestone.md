# Elmwatch visual and interior-navigation milestone

This milestone builds on the playable home/town and the unique NPC presence system.
It is on `cottage-interior-tutorial`, not yet merged into `main`.

## Integrated into current Godot builds

- [x] Updated Elmwatch painted outdoor scene and four approved building interiors.
- [x] Town roof, fountain and well collision aligned with the replacement map.
- [x] Existing staff occupy one place at a time according to world time.
- [x] Indoor collisions for Guild registrar desk, Market counter, Inn bar/tables and Blacksmith forge/anvil.
- [x] Staff moved onto reachable walkable staging locations near counters.
- [x] Doorway paths and exit interaction preserved, including the cottage and all four shops.
- [x] CI tests interior obstacles, worker interactions, safe door returns and bedroom regression.
- [x] Native Godot screenshots generated during push validation.

## Exact approved cottage image

The previously approved illustrated cottage foyer shows an empty wooden room,
green-patterned rug, green curtains, hanging foliage, warm lamps, center window and
a south doorway. The **source image is known and recovered**, and the visual-layer
adapter is committed as `tools/apply_cottage_visuals.py`. Its expected art path is
`assets/interiors/starter_cottage_foyer.jpg`.

- [ ] Import that approved JPEG **as actual binary repository content**.
- [ ] Only then activate `python3 tools/apply_cottage_visuals.py` after
  `tools/apply_interior_navigation.py` in *all three* workflow reconstruction sections.
  The adapter intentionally fails rather than silently substituting the old artwork
  when the required file is missing.
- [ ] Re-run Godot import/test and verify the cottage screenshot displays the
  illustration, not just the procedural prototype.
- [ ] Revisit the cottage hot spots for the hearth, pantry, travel map and table.
  The approved illustration is a **foyer**, not a full kitchen/living-room painting;
  a future connected room/background pass will give those rooms their own art.
  Until that art is integrated, **retain the functional one-time pantry potion** and
  tutorial transitions—never quietly remove gameplay for visual reasons.
- [ ] Dedicated painted blacksmith exterior and final accurate door alignment.
- [ ] Separate foreground overlays/occlusion and further mobile-scale collision polish.

### Existing furniture and scope protection

Do not bake the player's bed, dressing mirror or storage chest into the bedroom
background. The free initial green oak bed, tall oak mirror and plain wooden chest
remain transparent standalone sprites with saved functional interactions.
Purchasable furniture and in-game gold economy remain postponed.

### Tests

The new `tests/interior_navigation_test.gd` is invoked after the prior nine
test suites in both push validation and manual Android exports.
