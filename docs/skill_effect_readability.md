# Skill-effect readability pass — October 16, 2026

This is a presentation pass on the existing game, not a new combat system.

- Retain all 24 names and semantic effect families, starter/mentor progression, cooldowns, damage, saves, assets and original compass icon.
- Arrowheads distinguish Ranger shots from a warm Firebolt and violet Soul Bolt. Trails are capped at 52 world units instead of painting the whole flight path. Projectile visuals have travel and impact phases; gameplay damage remains immediate as before.
- Frost Nova uses branching ice spokes; Meteor Burst has a falling fire core and shockwave. Arcane Barrier is a stable hexagonal ward; Sacred Shield uses a shield silhouette. Earthshaker uses cracks, Hunter's Mark a fixed target reticle, summons a rising skull/rune cue, and Life Drain inward-moving motes.
- Hold opacity until late in the animation. Draw dark contrast edges on key lines to keep effects visible on the approved painted terrain. No new textures, particles, labels or input controls are created by an effect node.
- These are cast/deployment cues, not persistent status-duration indicators. Persistent trap/ward/summon art remains separate work.
- Before damage runs, resolve this cast's target positions using the existing skill range, trap walkability and Shadowstep endpoint rules. Do not change those gameplay rules. Quick Volley sends cues only to its actual targets, capped at three.
- The existing screenshot runner will produce deterministic six-class galleries without the HUD and a separate HUD-on gameplay capture. Gallery labels are review-only and never added to the live ability implementation.

Validation is not implied by this document. Consult the Actions run on the resulting commit for executed regression and screenshot results. Android export remains manual; this pass does not request an APK.
