# Adventure Odyssey — Next development track

Reconciled October 16, 2026 against the existing GitHub game systems and the cottage customization milestone. **Continue the current 2D top-down Godot game, not a reboot.** No APK exports or changes to the original AO app icon until separately approved.

## Confirmed already implemented

- [x] Six classes (Warrior, Ranger, Mage, Necromancer, Assassin and Paladin) and customizable layered characters; no class gates on weapons, armor or accessories.
- [x] Free allocation of five stat points categories, weapon-type proficiency, inventory, visible gear, shops, equipment icons and saves.
- [x] One-bedroom starter cottage, foyer, kitchen/living room, storage/mirror/bed interactions and guided tutorial.
- [x] Elmwatch town NPC schedules, shops, dialogue, mentor quests and skillbook/quest journal.
- [x] Eighteen class starter skills with distinct icons; advanced mentor techniques unlock via class questlines.
- [x] Thornbrook enemies, Oldstone boss prototype, loot materials, independent rare equipment drops and distinct gold/Sigils.
- [x] Cottage Sigil bundles and new individual earned-gold furniture shop, artwork and save-safe equipping.
- [x] Godot automated regression validation and screenshot capture through push CI (manual Android export only).

## Next milestones in recommended order

### 1 — AI and combat state polish

- [ ] Review existing wolf, goblin, Thorncap and Guardian behavior using the current monster implementation. Do not replace the functioning slime and boss systems.
- [ ] Test wander → detect → pursue → attack/telegraph → retreat/leash → resume, including obstacle edges, damage, death and dropped loot.
- [ ] Address only demonstrated bugs in pursuit timing, target distance, death cleanup and room/map transition resets.
- [x] Add deterministic Godot tests for common creature states, real-rock obstacle detours, anti-overlap movement and boss telegraphs. No enemy balance changes.
- [ ] Inspect live enemy encounters and obstacle behavior visually on emulator.

### 2 — Skill visual effects and mentor progression

- [ ] Review all 18 starting skills and six mentor skills before generating new art; keep existing mechanics, names and unlocked saves.
- [x] Replace name-hash effect selection with named native-rendered patterns for all 24 skills; screenshots captured in CI.
- [ ] Refine and approve all distinct visual effects at native gameplay pixel scale.
- [ ] Verify cooldowns, combat/casting animation hooks, quest unlocks, HUD readability and saved mentor progress.

### 3 — Visible equipment production-art review

- [ ] Inspect the current 8 body variants × 4 directions × 3 frames, 34 equippable catalog designs and existing worn layers.
- [ ] Improve mismatched attachment placement and item icon/worn-gear pairs while retaining original item designs.
- [x] Ordinary ATTACK and successful skills use existing registered source poses with synchronized equipment frames.
- [ ] Add bespoke attack/cast animation art and visually approve gear mixes before production lock.

### 4 — World expansion and quality pass

- [ ] Expand existing Thornbrook/Oldstone exploration and quest branches without duplicating areas or NPCs.
- [ ] Add world navigation, combat UX and accessibility improvements based on visual walkthroughs.
- [ ] Test save compatibility, startup/tutorial path, touch-safe landscape UI, memory use and emulator/device performance.

### Release gate

- [ ] Request separate approval before exporting any signed Android APK or AAB.
- [ ] Keep exact AO compass icon and approved artwork unchanged unless a particular asset edit is explicitly reviewed.
- [ ] Maintain playable existing source, automated validation and visual preview artifacts at each meaningful milestone.
