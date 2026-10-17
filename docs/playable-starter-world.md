# Playable starter-region checkpoint

The bedroom door now opens the actual 4608×3072 ground scene. It uses the same local character, customized skin/eyes/hair, starter armor and equipped class weapon. Home interaction returns to the bedroom door. Bag/equipment, analog joystick, keyboard, click-to-walk, modal/focus input resets and save failure messages reuse the established bedroom controls.

World origin is the northwest corner (0,0), one native ground texel per world unit. Normal view is 1:1, character visible height ~96 units, travel155 units/sec. The approved six-pose walk cadence remains9fps at full movement. Camera bounds keep the entire actor inside the region at its outer limits. Ground streams padded512px chunks with128px prefetch; offscreen textures are released. The full-region screenshot uses a diagnostic0.5 zoom, not the normal cache/performance budget.

Location is an optional, validated extension to local save version5. Older v5 saves start in the bedroom. Scene transitions and Save & title persist atomically; the world also checkpoints position every10seconds. Failed writes retain the prior saved location and prevent a transition. Invalid or newly obstructed saved world coordinates fall back to the home entry. No network account or authoritative backend exists.

## Building artwork still required

The11 reserved polygons remain provisionally solid and unpainted. They are planning constraints, not invisible finished buildings. Core required art: player home exterior matching the bedroom door, guild, blacksmith/workyard, apothecary, general store and town homes. The proposed allocation and exact footprints are in building-placement-plan.json. No placeholder building art is substituted. Entry/return currently uses the home approach interaction; the actual door facade awaits artwork.

Water-bank and rock colliders are provisional traced geometry. Five72px approach routes are protected. This is a playable terrain/scenery checkpoint, not a completed populated town, quest/combat/tutorial or Android performance certification. No APK is built until the map is finished.

## Scenery and verification

142 placements use all51 approved asset types, including woodland clusters, meadow details, rocky outcrops and an arranged town-edge well/rest-stop with a supply nook. Ninety foot-level collision rectangles leave the five approach routes clear. Decorative ground vegetation has no collision. Feet determine actor/prop depth; full-canvas anchors preserve source registration. The L-wall and diagonal logs currently use conservative rectangles, not precise compound geometry.

Original artwork is untouched. Aspect-preserving runtime copies have a512px maximum edge, with exact source/runtime hashes in world-scenery-assets.json. The51 unique scenery textures total42.19MiB decoded RGBA; ground caching is additional. This is an asset estimate, not measured process/VRAM or Android performance.

The large traced river polygon exposed a rare engine point-in-polygon false positive during actual movement, missed by coarse route samples. A float64 half-open ray confirmation removes that snag without changing the water outline. Tests now drive actual swept movement along each protected route as well as checking its72px clearance.
