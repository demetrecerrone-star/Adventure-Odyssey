# Personal dialogue and character posture

This bounded polish builds on the hidden-stick, movement-speed, and road-guidance fixes.

## Conversations

The existing tutorial sequence and save transactions are unchanged. The receptionist is protective rather than administrative, the smith remembers being taught, the apothecary notices the adventurer's nerves, and the storekeeper treats the ring as something entrusted to them. Town residents speak as neighbors. Neither the ring's giver nor the protected family backstory is revealed.

Each service NPC offers an optional personal question and “Not right now. I'll come back.” The fixed close button also says “Not right now” whenever a progression action is available. Asking a question is local presentation only; returning restores the original briefing. Deferring emits dismissal only. A pending transaction still blocks duplicate acceptance, and reopening reads the authoritative saved stage. There are no new relationship points, hidden commitments, branching quest flags, gifts, or costs.

The meadow briefing retains its actual west-bridge/south-branch directions, three-slime target and 25-gold reward. Detailed equipment, skill, potion, and free-retry advice is an optional conversation so the Accept button remains fully visible on a 640×360 phone view. Both choices remain available without accidentally accepting the assignment.

## Character adjustment

The original painted sheets, all six classes and both character bases are preserved. A four-source-pixel local head lift tapers through the neck; its horizontal mask leaves the outer shoulders and arms fixed, and it reaches zero below source row 108. Both body and armor sample the same remapping, avoiding visible gaps at their alpha cutouts. Hair follows the head. A maximum 0.8-source-pixel addition follows the walking stride. This is not a whole-body bounce: foot pivot, collision geometry, held weapons, animation frame progression and 186 px/s travel are unchanged. Six authored walk drawings still play at the established 9 fps cadence. Idle is stable. Missing appearance masks disable the adjustment rather than separating layers.

The original outfit now uses a neutral armor shader with dye strength zero; paid armor dyes use the same posture mapping with their existing pigment settings. Bed materials default to zero head lift and are unaffected. Source art is not overwritten.

## Verification

- Personal dialogue regression covers every tutorial stage with repeated questions, return, defer, reopen and no transactional signals.
- Character posture regression covers 12 character identities, four directions, all three armor palettes, stride bounds, idle reset, paired layers and stationary foot pivots.
- Native comparison captures show all 12 characters in four directions. A four-second rendered walking video exercises every direction at 36 capture frames per second.
- Native phone dialogue captures cover 640×360 and 844×390. The full retail tutorial walkthrough again checks actual interaction buttons and collision-resolving travel from fresh and migrated saves.
- Source and packaged CI loops include both new regression suites. This milestone prepares Android version code 12 with the existing package and signing identity.
