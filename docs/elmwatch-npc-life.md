# Elmwatch NPC life — milestone 3

This is a **playable local prototype**, not the final MMORPG NPC system.
Installed after the town-art patch by `tools/apply_npc_life.py` and
`tools/apply_npc_interactions.py`. The permanent v0.3 source archive is unchanged.

## Current game-time behavior

- A new adventurer starts at **9:00 AM**, with a compact HUD clock.
- The clock advances by 1.5 in-game minutes per real second (a full day takes
  16 minutes of active play). Modal dialogue pauses local world simulation.
- Game time is stored in the existing offline save. Older saves safely default
  to 9:00 AM.
- Shop shifts are **7:00 AM–11:59 AM** and **2:00 PM–6:59 PM**.
- Lunch/break is **noon–1:59 PM**; town evening social time is **7:00–9:59 PM**.
  The residents are off-scene **10 PM–6:59 AM**, representing rest at homes.
- On outdoor intervals, residents follow short waypoints and switch walking
  direction frames. Their sprite resets to the idle frame when stationary.
- These schedules are temporary; future NPC homes and full navigation
  will support walking between actual doors instead of changing scenes
  immediately on scheduled time boundaries.

## Existing residents (preserved)

| Character | Primary role | Town district | Interior |
|---|---|---|---|
| Ilyan Crest | Guild registrar | Southeast guild | Guild desk |
| Captain Elara Voss | Warrior mentor | Guild approach | Guild training |
| Mara Fenwick | General merchant | Northeast market | Market counter |
| Tamsin Reed | Innkeeper | Northwest inn | Tavern bar |
| Brann Ironhand | Blacksmith | Southeast workshop placeholder | Blacksmith |
| Garrick Thorn | Ranger mentor | Eastern approach | Outdoors |
| Sister Sera Vale | Healer | West-central town | Outdoors |
| Neris Crowe | Necromancy scholar | Southern square | Outdoors |

Each indoor resident uses the existing NPC sprite, name, role, dialogue
component and advice system. The Guild has two indoor residents; the Market,
Inn and Blacksmith each have one. A **single-presence rule** now puts staff
inside their buildings during work shifts, outside during breaks and evenings,
and entirely off-scene overnight. At 9 AM the town has three outdoor residents
(Garrick, Sera, Neris), while shops have their corresponding workers. At lunch
and after 7 PM until 10 PM, all eight residents can be met outside; after
10 PM everyone is off-scene. No named NPC is simultaneously spawned inside
and outdoors. The roster automatically refreshes on hour-boundary transitions
without restarting the game scene.

## Functional interactions

- Talk to nearby characters via **TALK / USE**, indoors or outside.
- Dialogue shows **ON BREAK** or **EVENING** where appropriate. Existing story
  greetings and unique advice are preserved.
- Sister Sera restores player HP and saves it.
- Captain Elara recognizes the three-slime training assignment both in the
  street and inside the Guild. Its first completion sets
  `guild_training_completed`, which persists in the local save. Repeated talks
  do not re-award or repeat the first-completion response.
- Merchant purchase interfaces are **not** added; currency and furniture
  upgrades remain deferred as requested.

## Technical guardrails

- Fixed NPC destinations use safe walking areas aligned to the approved
  `elmwatch_village_new.jpg` illustration.
- Resident movement respects the same map collision function as the player
  and avoids directly stepping into the player. Idle and directional walk
  frame regression tests now run with every push.
- Doors, home storage, character mirror, quest kills, save/load and NPC dialogue
  are covered by the existing and new Godot regression scripts.
- The blacksmith entrance still needs its own illustrated exterior. Interior
  counters are part of a single painted background, so draw-order and
  foreground occlusion are not yet final.
- Future online multiplayer must replace the local simulation with
  authoritative world time and synchronized NPC positions.

Next suggested pass: inspect in-engine screenshots on a phone, adjust spawn
markers and obstacles to the approved painted counters and doors, then add
independent citizens with social behaviors rather than only the eight named
quest/service characters. Shop owners currently change scene presence at
the time boundary rather than physically walking through doors.
