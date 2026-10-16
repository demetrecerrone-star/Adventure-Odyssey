# Adventure Odyssey — Visible Equipment & Character Sprite Roadmap

**Status:** Planned; track verified progress by changing `[ ]` to `[x]` only after the stated acceptance checks pass.
**Source of truth:** This list supplements the current Godot 4.7.2 project; it does not replace the approved character designs, original recovered equipment concept sheets, or AO compass app icon.
**Release constraint:** Do not produce a new Android APK until emulator/device validation is intentionally requested.

## 0. Existing foundation (already implemented)

- [x] Eight selectable body/appearance variants with separate hair sprites and four-direction character preview.
- [x] Six character classes: Warrior, Ranger, Mage, Necromancer, Assassin, Paladin.
- [x] Unrestricted equipment use across all classes.
- [x] Seven persistent gear slots: weapon, armor, head, cloak, gloves, boots, accessory.
- [x] Integrate 39 recovered-art-derived inventory icons: 12 weapons, 12 armor pieces, 10 accessories, 5 materials.
- [x] Connect existing item icons to equipment, backpack and shop menus; save/load equipped items.
- [x] Godot automated item art/equipment validation was passing at the last reported equipment milestone.
- [x] Prototype source-derived underwear/base and independently rendered starter top/bottoms/footwear sprites in Godot; **visual approval still pending**. ✅
- [ ] Visible *equipped* armor, hoods, gloves, cloaks, boots, accessories and weapons on player sprites (not yet built; do not confuse with working equipment menus).

## 1. Sprite reconstruction (first visual review milestone)

- [x] Inventory all eight original source characters: 128 px high, 74–79 px wide depending on variant; 4 directions × 3 frames per body, centered Sprite2D with bottom-aligned anchor; clothing is baked into the source pixels. Audit recorded at `screenshots/ao_character_sprite_baseline_manifest.json` in CI artifact. ✅
- [x] Back up all original eight body variants and separate hair sprites before edits: 240 original PNGs in `ao_original_character_sprites.zip`, plus SHA-256 manifest. Archived original source ZIP in `payload/` remains unchanged. ✅
- [x] Produce the **first reconstructed underlayer prototype** for all 96 body frames from unchanged original artwork, with independent starter top, bottoms, and footwear frames. Godot rendering and regression checks passed on run 38907028048. ✅
- [ ] Polish and approve the underlayer base art: remove remaining baked clothing artifacts, refine bare feet, preserve faces/skin/hair, and compare at gameplay scale. The first pass is **not final art**.
- [ ] Add permanent opaque, nonsexualized underwear as part of each base appearance (practical shorts; appropriate coverage on all character variants). Characters must never render unclothed.
- [ ] Export matching idle/walk/combat directional frames for all eight body variants, preserving the project's native pixel resolution, frame registration, and alpha.
- [x] Capture actual Godot-rendered 8-variant × 4-direction comparison grids for underwear prototypes and starter clothes (GitHub Actions run 38907028048, visual QA artifact). ✅
- [ ] Obtain visual approval and finish per-pixel corrections before treating these prototypes as final production artwork.

**Acceptance:** All eight variants render with consistent proportions and alignment facing up/down/left/right; skin/hair variations work; no naked frame, missing pixels, or baked clothing showing through.

## 2. Clothes and equipment layering

- [x] Create separate and independently rendered starter top, starter bottoms, and starter shoes layers for all 96 original character frames; existing outfit is reconstructable and Godot tests pass. ✅
- [ ] Finalize the chosen starter trousers/shoes designs and ensure they sit cleanly over approved underwear bases at every frame.
- [x] Implement per-facing layered draw order and starter-clothing occlusion in Godot: cloaks behind/front for back-facing, armor over top, gloves/boots on limbs, hood above or masking hair, and weapons/accessories attached to the full-frame sprite. Engineering check passed. ✅
- [ ] Manually polish any remaining overlapping pixels in every animation; technical z-order is not final visual approval.
- [ ] Use shared per-frame attachment points / offsets so gear follows walking, attacks, skills, turns and idle animation.
- [x] Wire all seven equipment visual slots to inventory equip/unequip events without class gates; handle blank slots gracefully and preserve save data. All 34 equippable catalog entries passed Godot visibility regression tests (run 38908862777). ✅
- [x] Add safe missing-art fallback (starter clothes stay visible, no unclothed sprite) and basic hood/hair occlusion handling. ✅
- [ ] Inspect each helmet + hairstyle combination and manually refine hair masks as needed.
- [x] Preserve existing equipment saves, with equipped visual layers resynchronized after saving/loading and map transitions; cosmetic style additions remain future scope. ✅

**Acceptance:** On an in-game test character, equipping and removing a hood, chest piece, cloak, gloves, boots and weapon produces correct visible changes with no obvious gaps or clipping while moving.

## 3. Matching gear artwork (item icon + on-character visuals)

- [ ] Agree a production visual standard matching Adventure Odyssey's modern anime-influenced top-down pixel art: readable shapes at game scale, consistent lighting, pixel grid and restrained effects.
- [ ] Preserve all 39 original equipment/material designs as references and backups; do not silently replace them with unrelated generated art.
- [x] Generate provisional, pose-aligned **wearable art previews** for 34 currently equippable items across 8 body variants × 4 directions × 3 frames (3,264 PNGs) from approved original item icon data, preserving names and item IDs. Godot tests passed. ✅
- [ ] Build paired **inventory icon + worn/held animation sprites** for all **12 weapons**, keeping weapon silhouette/design consistent between them.
- [ ] Build paired **inventory icon + worn sprite layers** for the **12 existing armor/clothing pieces**, covering torso, hood, cloak, gloves and boots according to item.
- [ ] Build matching icons for **10 accessories** and tasteful on-character wear points or subtle readable visual cues where tiny pixel-scale details would otherwise disappear.
- [ ] Finish/retain **5 material icons** (materials do not need worn sprites).
- [x] Link equipment visuals using the same catalog ID and approved icon-derived colors; production sprites can override prototypes per item without changing saves. ✅
- [ ] Preserve ability to add leg armor, shields/off-hand items, dye variants and cosmetic outfits in later milestones without breaking existing saves. These are future additions, **not** among the current seven slots.

**Acceptance:** Visual inspection confirms each illustrated worn item matches its icon's color, silhouette and motifs. All item IDs resolve without broken textures; the original recovered artwork remains untouched.

## 4. Game integration and regression tests

- [ ] Implement the Godot equipment visual controller using body variant, direction, animation frame, equipped item IDs and saved appearance.
- [ ] Keep stats, weapon proficiency, gold/shop systems, skill effects and the 18 starting abilities independent of clothing visuals.
- [ ] Add automated checks for layer presence, item-to-sprite lookup, equipped/unequipped changes, save compatibility, and fallback behavior.
- [ ] Test **8 body variants × 4 facing directions**, representative idle/walk/attack frames, all **6 classes**, and mixed equipment combinations.
- [ ] Verify accessibly sized equipment/menu icons and no touch HUD overlap on the Samsung Galaxy S23 FE landscape target.
- [ ] Capture and share **actual Godot screenshots**, not visual concept art, of base underwear, starting clothes, fully equipped characters, inventory icons, and the character moving in four directions.

**Acceptance:** Godot import, automated gameplay tests, visual QA, and save/load regressions pass; screenshots approved before declaring art integration complete.

## 5. Android acceptance and release

- [ ] Verify gameplay and appearance using an Android emulator before authorizing a new APK (retain current restriction).
- [ ] Check Android landscape sizing, touch controls, performance, asset memory, animation alignment, and save reload on representative emulator/device configuration.
- [ ] Check presentation against applicable Google Play sexual-content rules; underwear must remain ordinary/nonsexualized and be properly covered in regular gameplay/store imagery.
- [ ] Only after approval, build and verify a signed test APK with the established key; keep the approved AO compass icon unchanged.
- [ ] Record final screenshots, CI result, commit ID, and any outstanding visual issues.

## Milestone review rhythm

1. **Base bodies + underwear:** review eight variants before equipment is drawn.
2. **Starter clothing + one test loadout:** review four directions and movement.
3. **Weapons / armor / accessories:** review icons next to actual character rendering in small batches.
4. **Full integration:** review inventory/equipment/shop plus in-world appearance and automated tests.
5. **Android:** emulator first, signed APK only when explicitly approved.

**Checking rule:** Check off a task only after files are committed and its stated validation has succeeded; a concept image or planned task is not the same as implementation.

### Baseline review

`tests/character_source_atlas.gd` emits a **native-source** 96-frame contact sheet for the 8 body variants, 4 facings and 3 walking frames. Columns 1–8 are appearances; rows are down, left, up, right, each with animation frames 0/1/2. This is a pre-edit visual reference, not a claim that reconstructed underwear or gear sprites exist yet. The original source PNGs and hair sprites are archived separately by `tools/audit_character_sprites.py` and verified by their SHA-256 hashes. Never alter their original copies.

### First-pass modular starter-sprite implementation

`tools/generate_character_layers.py` now generates **384 separate full-resolution PNG layers** (8 bodies × 4 facings × 3 animation frames × underwear body/starter top/starter pants/starter shoes) *deterministically from the archived originals*, without overwriting them, using only the Python standard library. `tools/apply_character_layers.py` wires the separate base and three starter garment sprites into the in-game character, keeping original hair, class, equipment stats and saves. **This is a visual prototype, not finished polished art, and equipment overlays still require separate bespoke worn sprites.** Before checking off the full reconstruction/art tasks, visually review output and fix fringing, original outline remnants and footwear silhouette. `tests/character_layers_test.gd` verifies all 96 appearances/directions/frames and alignment, equipment compatibility and transitions. CI does not build an APK for pushes.

### Equipment attachment interface milestone

`tools/apply_equipment_visuals.py` creates seven correctly ordered Sprite2D gear nodes on the actual playable character and keeps them in sync when equipped items, direction or animation change. It looks up only purpose-drawn 128px-height pose-aligned worn textures under `assets/equipment_worn/<slot>/<item_slug>/base_variant_NN/<direction>_<frame>.png`. **These individual textures have not yet been finished**, so the nodes remain hidden and the default outfit stays visible (no fake enlarged inventory icons or unclothed frames). No class gates or save format changes. `tests/equipment_visuals_test.gd` verifies seven slot nodes, equipment changes, missing-art fallbacks and walking-frame updates.

### First-pass worn-item preview stage

Generator `tools/generate_worn_gear.py` prepares 34 prototype worn sprites using original recovered-icon motifs and palette, across all eight body types, four directions and three frames. `tools/apply_equipment_visuals.py` is the sole renderer; it prefers production artwork under `assets/equipment_worn/<slot>/<slug>` and temporarily falls back to `assets/worn_gear/<slug>` when no approved production overlay exists. No second conflicting appearance renderer is run. The art is FIRST PASS ONLY, not approved final art; original inventory icons and sprites remain untouched. Tests validate equipping, seven slots and saved items.

### Matched wearable equipment art, second visual review milestone
`tools/generate_worn_equipment_art.py` generates 3,264 **individual, frame-aligned 128px body-size** transparent worn sprite layers for all 34 equipable items (12 weapons, 12 armor, 10 accessories) covering eight body variants, four facing directions and three movement frames. This is *new hand-authored first-pass pixel art* using a palette matching the item motifs, not replacements for the four approved concept sheets. Alongside worn art it generates **34 alternate icon previews** in `assets/equipment_item_icons/` cropped from the very same worn sprites. Original `assets/items/*.svg`, body sprites, compass icon and saved item IDs stay untouched. The seven-slot Godot renderer already prioritizes these full-size correctly attached sprite layers over the old proof-of-concept enlarged icon visual fallbacks. `tests/worn_equipment_art_test.gd` checks item/slot parity, icon dimensions, every body/facing/frame, six-class equip freedom and saves. Native Godot QA captures full loadouts and all alternate icons; do not mark final art approved until reviewed.
