# Independent wilderness groups

The South Meadow always contains a bounded group of three slimes; the western woods contain two wolves. Neither group requires a guild assignment, and finishing a quest does not remove monsters. Roadside signs name both destinations; slimes also have legible name labels. The existing gold route trail still guides accepted assignments.

Each defeated monster returns after 25 real-time seconds at its original home. Idle monsters wander within a small radius; chase/attack movement stays inside the group territory. The main road, town, home and retry approaches are outside these combat territories. Menus pause combat, while the saved respawn deadline continues to elapse.

The first life of each original spawn retains its existing gold/XP/Sigil reward. Subsequent lives award the same normal gold/XP and no additional Sigils. Values remain provisional: slimes 3 gold/10 XP, wolves 8 gold/35 XP. Five fixed generation counters plus deadlines replace an unbounded per-kill log. Controllers submit the exact rendered incarnation; replaying an older dead life can never pay again, even after its cooldown.

Schema 13 migrates the old first-kill receipts without granting anything again. Old cleared monsters return as new lives. Completed quests stay completed, and active old assignments retain their verified partial-kill credit. Only kills made after accepting an assignment count toward its three-slime or two-wolf objective. Kill rewards, level-ups, quest credit/completion and resource changes save in the same atomic transaction. Failed writes pause combat and preserve the unpaid incarnation for retry.

Offline cooldowns use the device clock; this is local single-player state, not a server-authoritative economy. No network service or real-money currency is introduced.

## v0.13 feedback refinement

Save schema14 shortens all existing v13 deadlines by exactly20seconds once. Already elapsed deadlines stay elapsed, and first-kill receipts, monotonic spawn generations, quest credit, coins/XP/Sigils and cosmetic ownership are untouched. Reloading schema14 does not shorten deadlines again.
