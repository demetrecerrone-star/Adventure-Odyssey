# Equipment inspection and atomic swaps

The bag sorts owned item types by label and opens a centered inspection popup. The equipped weapon, armor and ring have tappable icons beside the saved layered character. Equip swaps an occupied weapon slot in one save transaction, returning the old instance to the bag; failed writes restore both containers and all instance metadata. Same-item swaps prefer the highest upgrade already used by inventory selection.

Inspection shows actual count, binding, class eligibility and implemented basic-strike damage, including Strength and weapon rank. Green/red comparisons describe only this damage, not unimplemented armor or class-skill scaling. Potions expose Use through the existing atomic resource/consumption service. Equipped items can be inspected and removed; fixed starting armor is informational.

New automated tests cover six-class found-stick swaps, rollback/reload and real phone UI button flows in both handed layouts. Native phone captures cover the popup and live character equipment. This milestone does not alter saves or require migration.
