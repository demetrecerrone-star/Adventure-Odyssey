# Registered class weapon candidates

Only the validated equipped class-specific starter weapon renders. Chest/bag ownership alone never enables the artwork. Equip, unequip, reload and failed-save rollback are tested. Warrior/Paladin swords, Ranger bow, Mage/Necromancer staffs and Assassin paired daggers have both-base registered layers.

Separate rear/front layers follow the same 256px cells and eight gait frames as both character bases. Draw order is rear weapon, body, armor, front weapon, hair. The whole avatar retains world foot-depth sorting, so furniture occludes its weapon with the body. Existing body and armor files are unchanged. Grip alpha is already baked into the front layer; no diagnostic grip layer is rendered.

This is a visual pilot, not combat. Existing open hands remain unchanged; side projection uses transformed flat art. Native pose and furniture-occlusion captures must be reviewed before an APK or public release.
