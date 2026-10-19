# Phone feedback refinement

Larger touch targets: Attack 112 px, skills 76 px, potions/menu 64 px. The three skills have equal 90 px center spacing and a separate action row. The identity panel and portrait are approximately 10% larger. Menu sits beside the identity block without covering its text. Narrow safe areas stack HP/MP to retain readable values.

NPC conversations request a 10% larger maximum panel, capped to the display with 10 px edge margins on short phones. Inventory and Character equipment icons form a centered bottom row,6 px gaps and 16 px bottom inset. The avatar has a reserved area above them; all actual equipped items, touch details and atomic swapping remain unchanged.

The three outdoor neighbors no longer repeat one farmer. The garden neighbor retains the original farmer; the plaza neighbor uses the original apron-clad roster art, and the wellside scholar uses a stable native render of approved male Mage/hair/skin layers. The guard and four already-distinct shop attendants retain their authored identities. Positions, facing, collision, interaction stands and conversations are unchanged.

All existing slime/wolf spawns now respawn after 25 seconds. Schema 14 shifts existing schema 13 cooldown deadlines 20 seconds earlier once. It does not change paid spawn generations, rewards, quest credit, Sigils or the intentionally overpowered stick.

Raise Skeleton uses new directional poses adapted directly from the canonical title-screen skeleton: bare skull, tan bones, leather shoulder armor and boots, blue cloth and sword. The original title art is unchanged. Real movement selects front/side/back walking; left mirrors right. Real summon attacks select strike/recovery art. Per-pose atlas regions and foot registration avoid clipping at regular-grid edges. The summon has its own depth-sorted world node and a subtle friendly ground ring. The weaker front/right windup pose is not used. Its existing damage, mana, cooldown, lifetime and rewards remain unchanged. This is a 2.5 D painted sprite, not a 3 D model.

Validation includes all six classes, both handed layouts at 844×390 and 960×540, inset-safe-area geometry, actual item popup taps, repeated timer migration/failed-save rollback, distinct NPC textures, and four-direction summon walking/attacks/expiry without renderer-driven damage. Native captures and motion are desktop Godot renders; no new APK or Android runtime verification is implied.

Local validation: 58 source suites passed, followed by focused reruns of HUD 1,489, touch layout 368, summon 68, all-class abilities 134 and field integration 528 checks. Native touch layout 394, item-popup 72 and summon 77 checks passed; six town views and a 5.3-second 30fps gameplay summon clip were reviewed at 844×390. These numbers are checked results, not a claim of Android-device execution.
