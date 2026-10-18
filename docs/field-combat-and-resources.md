# Field combat, resources and Western Forest patrol

This milestone keeps the six existing classes and all 18 archived skill names. The three field buttons and keyboard 1/2/3 now execute real effects; F remains a free basic strike. P opens field supplies. Secondary-touch release works while another finger holds movement; cancellation, dragging away, focus loss and modal opening discard held actions.

## Playable sequence
Complete the existing letter/guild/shop tutorial, accept and clear the three South Meadow slimes, then report for 25 gold. The guild offers a second assignment: cross the west bridge and follow the northern trail into the Western Forest. Defeat two wolves and return for 40 gold, once. Quest receipts suppress cleared encounters after reload. Monster gold, character XP and Sigils are now awarded separately; see monster-xp-and-sigils.md.

## Resources and recovery
Save schema 10 retains the permanent save slot and migrates schema 9 with full initial HP/MP once. Actual HP/MP, three skill cooldowns and the shared potion cooldown persist. Skills save their cost before effects are accepted. Damage checkpoints immediately; unpaused mana recovery/cooldown time checkpoints at most every five seconds and on interactions. An unavailable save pauses combat and retries; rejected casts roll back both effects and costs.

Healing potions restore up to 40 HP; mana potions restore up to 25 MP. Both share a three-second cooldown. Empty/full-resource/dead/cooldown requests consume nothing. Each consumption receipt removes exactly one owned stack item and conserves acquisition totals. Starter, tutorial and purchased goods retain their character binding. Retry and reload never refund consumed potions. Defeat offers free full HP/MP recovery with only undefeated monsters reset. Basic attacks need no mana, so exhausted supplies cannot lock progression.

Temporary buffs, summons, traps and surviving enemy wounds reset on re-entry; defeated spawn receipts, paid mana and cooldowns persist. Menus pause combat and recovery. Interiors display persisted resources; supplies and combat actions are available in the field.

## Active stat boundary
VIT-derived HP, WIS-derived mana capacity and WIS mana recovery are live. Basic damage is 12 plus one per weapon upgrade plus half of STR above 10, rounded down. Other displayed probability/damage/armor formulas remain previews and are labeled accordingly. Skill damage, mana costs and durations are provisional fixed per-class tuning; the original skill identities are preserved. Luck XP/discovery receipts, level allocation and ownership rules are unchanged.

## Effects
- Warrior: Power Slash damages nearby targets; Shield Bash damages and stuns; Battle Cry increases basic strike damage temporarily.
- Ranger: Aimed Shot hits at range; Quick Volley damages nearby targets; Snare Trap slows enemies entering its radius.
- Mage: Firebolt burns; Frost Nova damages and slows nearby targets; Arcane Barrier blocks two hits.
- Necromancer: Raise Skeleton creates a temporary attacking summon; Soul Bolt hits at range; Life Drain damages and restores HP.
- Assassin: Backstab gains damage against idle/returning enemies; Shadowstep moves into attack range along a clear path; Poison Blade applies damage over time.
- Paladin: Holy Strike deals damage; Divine Heal restores HP; Sacred Shield blocks three hits.

Native-rendered phone captures exercise all 18 actual buttons, mana/cooldown changes and effects, plus both potion choices. Dedicated model, save, live input and forest integration tests cover retries, reloads, failed writes, source conservation and one-time rewards. These checks are included in CI; local rendering is not a substitute for an Android device build.
