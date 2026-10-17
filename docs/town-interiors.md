# Four town interiors: bounded travel and static NPC checkpoint

This pass adds Adventurer Guild, blacksmith, apothecary and general store rooms.
It preserves the existing painted world, fortifications, bedroom and layered player.
Each exterior approach saves the destination before routing; returning saves that
specific exterior approach before changing scenes. Failed saves leave the current
scene and saved location unchanged. Save & title and Continue retain the room.

Room locations are whitelisted and bounded to 1536×1024; world remains4608×3072.
Old saves without a location retain the existing bedroom fallback. No inventory,
chest, equipment, appearance or tutorial reward changes are part of this pass.

The shared room renderer uses separate plates, furniture and static NPCs with
source anchors, uniform scales and foot-depth ordering. Collision uses the authored
floor polygon and16px-inflated furniture/NPC footprints. Joystick, keyboard, bag,
equipment and modal input reuse the bedroom implementation. The room player stays
at1.05scale (~200px visible authored height); exterior stays96px.

All NPCs are static down-facing art. The clerk, smith and shopkeeper reuse recovered
painted role assets; apothecary is newly painted. They have no invented names or
backstories. Interaction opens a truthful welcome/status panel; service economy,
quest grants, upgrades, potion rewards, ring progression and combat remain pending.
There are no prices, stats or reward claims fabricated for these rooms.

Art sources and proposals remain separately preserved under ao-town-interiors.
Runtime copies use room-specific layout.json and local filenames. Guild selects
room-v2.png with a blank wall for the separate noticeboard. Original source alpha
can contain very low-opacity fringe pixels; final native scene review is required.

QA includes strict save/routing rollback tests, input/modal handling, entry-to-NPC
reachability, physical furniture, and native captures of entry, attendant, counter
occlusion, phone dialogue and the correct exterior return for all four rooms.
Desktop native captures do not establish physical Android performance. No APK is
requested by this checkpoint; the user's map-completion hold remains in effect.
