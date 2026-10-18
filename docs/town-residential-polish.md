# Residential town polish checkpoint

Base: c4138f92cebc812f85ef1f9960034b0a2fcd5207 (tutorial/sideways shops, QA345).

The existing three town homes gain small distinguishing gardens/firewood. A communal well and bench occupy the eastern green, and one lamp marks the west plaza edge. Three existing-art residents and one gate guard stand on safe verges, using their actual directional idle sprites at96px visible height. No original terrain, house, shop, wall or gate art is changed.

All13 placements use existing approved assets. The open central plaza stays open. Source raster checks report zero new footprint overlap on the five protected72px routes or four gate traversals; NPC interaction stands remain reachable at both16px runtime and conservative36px clearance. Engine checks validate resident stands, solid feet, targeted conversations, movement blocking/reset and unchanged quest/inventory when residents speak.

Residents offer short geographic guidance only. They grant no quests or items and do not pretend to wander or trade. Homes still have exterior-only doors; this checkpoint does not invent house interiors. Market-stall artwork is missing and remains deferred. Outer-region ambient creatures remain a separate queued pass.

Source checks: starter world3846 and resident58 pass. Native camera, depth and phone conversation captures are required before calling this checkpoint visually verified. No APK is requested by this source change.

Follow-up UI/depth fixes: the keepsake ring appears on Character, equipped weapons show their actual +1 metadata, and an attendant remains below a player walking in front of them while staying behind its paired counter. Scene tests now include eight below-attendant ordering probes.

Combined source regression: 22 suites39,819 checks plus title272 =40,091 passing checks. Focused reruns after interaction-radius hardening pass resident58, scene75 and world3846. Native review is pending.

Smith confirmation refinement: opening the upgrade service is read-only. The player must select the carried starter weapon, then confirm the free +1. Back leaves state unchanged; failed writes keep a retryable selected panel. Secondary-finger activation, canceled touches, drags and focus loss are covered. Native captures include the selection and confirmation screens.
