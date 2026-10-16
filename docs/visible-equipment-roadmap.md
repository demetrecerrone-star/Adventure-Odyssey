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
- [ ] **Not implemented:** clothing-free base sprites, independent underwear/starter clothes layers, or visible equipment overlays on the moving character. Existing appearance variants contain baked-in clothing.

## 1. Sprite reconstruction (first visual review milestone)

- [ ] Inventory every source character's frame dimensions, pivot/anchor, facing directions, animation count, proportions, and existing clothing areas.
- [ ] Back up all original eight body variants and their directional sprites before any edits.
- [ ] Reconstruct neutral base-body art **from existing character artwork** without changing identity, proportions, face, hairstyle, or skin palette. Since clothing is baked in, redraw covered regions; do not assume deleting pixels yields a usable body.
- [ ] Add permanent opaque, nonsexualized underwear as part of each base appearance (practical shorts; appropriate coverage on all character variants). Characters must never render unclothed.
- [ ] Export matching idle/walk/combat directional frames for all eight body variants, preserving the project's native pixel resolution, frame registration, and alpha.
- [ ] Show actual in-engine comparisons of original sprites and reconstructed base sprites for approval before changing production visuals.

**Acceptance:** All eight variants render with consistent proportions and alignment facing up/down/left/right; skin/hair variations work; no naked frame, missing pixels, or baked clothing showing through.

## 2. Clothes and equipment layering

- [ ] Create separate starter-shirt, trousers and simple-shoes sprite layers that fit the new bases; these remain visible in uncovered regions.
- [ ] Define explicit draw order/occlusion by facing: cloak behind body, torso armor above undershirt, gloves above arms, boots above shoes, headgear with hair clipping/masking, and weapon attached to hand.
- [ ] Use shared per-frame attachment points / offsets so gear follows walking, attacks, skills, turns and idle animation.
- [ ] Wire equipment visuals to the existing seven gear slots without class gates; support equip/unequip without restarting scenes.
- [ ] Preserve hair/helmet compatibility and add fallback visuals when an item lacks a production-ready equipped sprite.
- [ ] Keep outfit, equipment selection and cosmetic choices persisted across save/load and transitions.

**Acceptance:** On an in-game test character, equipping and removing a hood, chest piece, cloak, gloves, boots and weapon produces correct visible changes with no obvious gaps or clipping while moving.

## 3. Matching gear artwork (item icon + on-character visuals)

- [ ] Agree a production visual standard matching Adventure Odyssey's modern anime-influenced top-down pixel art: readable shapes at game scale, consistent lighting, pixel grid and restrained effects.
- [ ] Preserve all 39 original equipment/material designs as references and backups; do not silently replace them with unrelated generated art.
- [ ] Build paired **inventory icon + worn/held animation sprites** for all **12 weapons**, keeping weapon silhouette/design consistent between them.
- [ ] Build paired **inventory icon + worn sprite layers** for the **12 existing armor/clothing pieces**, covering torso, hood, cloak, gloves and boots according to item.
- [ ] Build matching icons for **10 accessories** and tasteful on-character wear points or subtle readable visual cues where tiny pixel-scale details would otherwise disappear.
- [ ] Finish/retain **5 material icons** (materials do not need worn sprites).
- [ ] Add metadata linking each item ID to the same art family for HUD, shop, backpack, equipment menu and character renderer.
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
