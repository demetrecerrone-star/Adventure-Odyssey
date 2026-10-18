# Lived-in interiors and character visibility

Fourteen separate decorative placements reuse existing approved painted art. No source image was repainted, mirrored or rescaled nonuniformly. Guild adds waiting bench, planter, side bookshelf and rug; apothecary adds bench, planter, side bookshelf and rug; general store adds stock barrel, crate and waiting bench; smith adds firewood, cooling-water barrel and stock crate. These are decorative, with no invented inventory or services.

All four attendants already face sideways toward the door/customer approach. Their original art and position remain unchanged. Explicit facing metadata and regression checks now require a positive facing projection toward entry and the interaction stand. Bedroom already has nine layered furnishings and remains unchanged.

Solid details have measured floor footprints, while rugs remain noncolliding at floor depth. The central entry lane and entry→NPC→exit routes remain clear. A separate audit checked 16px and stricter24px clearance on a10px grid; runtime tests sweep actual collision routes. QA355 native phone/desktop entry and attendant captures passed independent scale, placement and depth review for all four rooms.

Exterior visibility fixes preserve every building/wall collision and depth boundary. Padded texture rectangles no longer trigger wall fading by themselves. Cached one-bit alpha masks test whether opaque foreground covers sample points on the player's head, torso, outer arms and boots. Genuinely obscuring walls and buildings fade locally to38% opacity; clear objects restore full opacity. Tests cover the false south-gate fade, true general-store overlap, and previously invisible reachable positions behind home/guild. No art, combat, save or character-customization changes.

This is a bounded QA-only checkpoint. Native software-renderer captures do not certify hardware Android performance. No APK is built.

QA355 caught narrow adjacent-wall clipping at the general-store approach. Lateral arm/boot probes now include both missed modules while preserving opaque walls beside the south gate. Exact regression: general-store [2502,1519.8], south_west_04_02 and south_west_03_00; native recapture pending.
