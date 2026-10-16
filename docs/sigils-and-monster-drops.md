# Adventure Odyssey — Sigils & Creature Loot

**Working game economy, 16 October 2026.** The second currency is officially **Sigils**, not diamonds. The coin is a gold rim with a royal-blue face and an embossed **AO** insignia/compass, visually consistent with the existing Adventure Odyssey icon. The approved **app launcher icon stays unchanged**. Godot currency asset: `assets/ui/odyssey_sigil.svg`. `tools/apply_sigils_currency.py` integrates the balance and in-game display; `tools/apply_monster_loot.py` integrates the creature rewards.

## Two balances, different purposes

- **Gold:** ordinary monster drops, equipment, potions, crafting/blacksmith services, inn rest, and routine furniture purchases when released. Existing equipment, NPC merchants and gold save data are preserved.
- **Sigils:** earned special currency for rare cosmetic furnishings, character appearance options and other *non-stat-changing* novelty items. This is not a cash-sales feature. Players start with **0 Sigils**; old save files gain a backward-compatible 0 balance.
- **Guild field training (one-time):** +5 Sigils in addition to its existing 20 gold and potion.
- **Oldstone guardian (one-time):** +25 Sigils in addition to existing 65 base gold, 100 bonus gold, experience, relic and Ember Shard. Guardian remains permanently cleared in the existing save flag.

Both balances can be seen in the game's HUD/backpack/decor interface. Sigils use a separate saved `sigils` integer; spending/earning never converts ordinary gold or changes free stat allocation, class skills, unrestricted equipment or progression gates.

## Monster loot profiles (early balancing values)

| Enemy | Existing guaranteed base gold | Additional gold | Guaranteed material | Optional rolls on defeat |
|---|---:|---:|---|---|
| Green slime | 3 | 0–2 | Slime Gel on the existing every-third-kill cadence | Slime Gel 35%; Health Potion 6% |
| Wolf | 6 (forest) / 10 (ruins) | 0–3 | Wolf Pelt, plus inherited Beast Hide | Beast Hide 55%; Health Potion 8% |
| Goblin | 8 (forest) / 11 (ruins) | 0–4 | Iron Ore | Additional Iron Ore 30%; Health Potion 10% |
| Fungus | 5 (forest) / 9 (ruins) | 0–2 | Herb, plus inherited Enchanted Thread | Enchanted Thread 45%; Health Potion 9% |
| Oldstone guardian | 65 + 100 fixed boss bonus | 8–16 | Guardian Relic and Ember Shard, first victory only | None |

### Independent RNG and extremely rare rewards

Each kill rolls each possible item **independently**, including rare items. A 0.25% drop has a real one-in-400 chance on *any* eligible kill, including the first. There is no minimum kill count, level gate, streak requirement, guaranteed pity drop, or progressive boost. The 0.25% is a probability per kill, **not** a promise of an item exactly once every 400 kills.

| Monster | Rare equipment (real catalog item) | Independent chance per kill | Bonus Sigil roll |
|---|---|---:|---:|
| Green slime | Slime Core Charm | 0.25% | 0.5% for 1 Sigil |
| Wolf | Forest Fang | 0.35% | 0.75% for 1 Sigil |
| Goblin | Guard Sigil | 0.25% | 0.75% for 1 Sigil |
| Fungus | Wisdom Bead | 0.3% | 0.6% for 1 Sigil |
| Oldstone guardian (one-time) | Ember Pendant | 3% | No separate repeatable Sigil roll; first victory still awards 25 Sigils |

Regular gold and the existing progression-friendly material cadence remain in place. Higher rarity is exciting but does not restrict class equipment access. The drop tables and tiny percentages are tuning values that can be adjusted after emulator/playtesting.

Enemy drops are rolled only on death; already dead enemies and claimed boss rewards cannot be repeatedly collected. Existing quest-kill counters, XP, 18 starting skills and 6 mentor techniques are not changed. Collected materials are added to the current backpack and persist using existing character saves. Materials can be sold from the backpack for gold: Slime Gel 2, Wolf Pelt 4, Beast Hide 5, Iron Ore 7, Herb 3, Enchanted Thread 6, Ember Shard 24.

## Cottage cosmetic guardrails

The original free **green oak bed, tall oak mirror and plain wooden chest** must remain permanently owned, with their established storage/mirror functionality unchanged. The Sigil cottage catalog includes placeholders for future art-ready upgrades, but it will **refuse to deduct Sigils if an actual matching furniture PNG is not installed**. Existing furniture art and ownership data are preserved. Avoid presenting concept-only artwork as already purchasable gameplay content.

Future Sigil cosmetics can include furniture color schemes, wallpapers, clothing dyes, pets and profile effects, subject to later design approval. They should be visible/customizable without combat power requirements. Price examples in code are balancing placeholders, not final prices.

## QA, packaging and review

- `tests/monster_loot_test.gd`: enemy loot, bonus coins, rare first-kill chances, no guaranteed rare pity, single-claim protection, Sigil rolls, material selling, persistence, boss uniqueness.
- `tests/sigils_currency_test.gd`: coin resource/HUD, earning/spending, older-save migration, zero-cost original furniture and art-gated purchases.
- `tests/guild_training_test.gd`, `tests/world_expansion_test.gd`: one-time Sigil quest/boss rewards.
- CI validates the reconstructed Godot source and game tests on pushes. **Do not build a new APK until emulator verification and user approval.**
- The currency icon is a *first-pass in-game vector interpretation* of the user-approved gold-and-blue AO coin concept, not a replacement for the original app icon. Review game-scale legibility before final art approval.
