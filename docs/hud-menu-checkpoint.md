# HUD and menu checkpoint

This pass adds the approved light ivory, engraved gold and turquoise interface to the existing bedroom, starter region and four interiors. It retains the actual layered player art and saved guest inventory.

## Functional scope

- Shared portrait/name/class HUD and scene-relative coordinate display.
- Menu pages for Character, Inventory, Stats, Quest Log and Settings.
- Inventory equipment changes use the existing atomic guest-save operations; inspection never equips an item.
- Device-local fixed/floating joystick mode and independent left-handed layout. Settings are separate from the guest character save and are applied only after successful atomic persistence.
- Opening or closing an overlay, changing layout, losing focus or leaving a scene releases movement input.

## Honest incomplete systems

Combat, health/mana, levels/XP, skill activation, minimap navigation and quest tracking are not yet implemented. Their interface locations are marked unavailable. The current item catalog defines class/type/slot but no numeric combat statistics, so attack power, luck and comparison deltas must not be invented. Potion counts may be displayed, but consumption remains unavailable.

## Verification

Source and packaged test suites, native landscape screenshots and signed Android export are required before delivery. Physical device acceptance remains a separate user test. The character save schema and permanent Android signing identity remain unchanged.

## Following checkpoint

After this UI APK is delivered, implement the separately approved tutorial/story and shop improvements, with side-facing attendants/counters and town/residential/environment polish. These changes are intentionally outside this APK's scope.

Local Godot 4.6.3 verification: 36,664 checks passed (31,464 existing regressions; controls 197; HUD shell 388; menu 357; combined integration 4,258). The combined tests include six scenes, two landscape sizes, all four control combinations, inset safe bounds, atomic-save failure rollback, real equipment changes, secondary-touch dropdown opening, outside dismissal and no floor-tap leakage. Floating activation zones have real horizontal origin travel, rather than a minimum-size pad that only looks fixed. Native Godot 4.7.2 capture and APK packaging are the next release gates.
