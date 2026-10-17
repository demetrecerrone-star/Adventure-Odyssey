# Painted town fortifications

The starter region now has 65 separate painted wall, tower and gate-post placements using 52 cropped textures. Seven town buildings lie inside the perimeter; the player's home remains outside. Four permanently open passages serve the west bridge, north trail, northeast foothills and south workyard. This checkpoint adds no gate locking, guards, combat or new interiors.

## Rendering and collision

Every placement preserves uniform native artwork scale and carries its measured ground polygon. The same polygon drives foot collision and per-X foreground sorting. Only an overlapping foreground fortification module becomes translucent (38% opacity) when it would hide the player; it returns to full opacity when the player moves in front or away. This keeps the southwest shop approach readable without moving the shop.

The steep bank runs use purpose-made masonry rather than the rejected repeated thin north-south strips. Footings follow supported rock/grass. Some footing pixels overlap a conservative river collision mask that includes bank rock; none overlap visually blue water. The original ground, scenery and eight building placements are unchanged.

## Verification

- All five protected 72px travel corridors remain clear.
- All eight building approaches remain connected to the plaza.
- Four gate corridors support swept movement in both directions.
- Every measured fortification footprint blocks feet.
- Depth ordering, local transparency restoration and town membership have regression checks.
- Native captures cover every gate from outside, center and inside, the existing building doors, home return, world motion and overview.

The old clear-neighbor cliff probe at (2978,405) is now legitimately occupied by the north wall. Its replacement at (2950,470) remains clear of both the cliff and fortification. The original blocked cliff probes are retained.

This remains a playable exterior checkpoint. Other interiors, NPC interaction, quests, combat and Android performance validation are separate work.
