# Tutorial and shop-facing checkpoint (source verified; native review pending)

Base: v0.10 HUD APK build343, source 5276febb0111a7ffd7ef25a721bc37b27295b1ed; release commit a34c42c0b26ad7dd5fc5c695d861415983b1208b.

## Scene integration
- A separate readable guild envelope lies beside the starter-home entrance at world (1708,1340). Home travel remains a separate interaction.
- The world/room controller saves its current location before opening the tutorial dialogue. Dialogue emits requests; Save owns proximity validation, inventory, binding, one-time receipts, upgrades and atomic persistence.
- The guild, blacksmith, apothecary and general store share the existing light ornate dialogue shell. Repeated actions refresh only after Save succeeds; failures leave the previous state intact.
- The HUD and Quest Log show the saved Tutorial objective and received gifts. Tapping the tracker opens the full quest details.
- The first upgrade applies +1 metadata to the existing starter weapon. Numeric combat benefits, paid trading and combat remain unavailable; no prices, damage or potion-effect formulas are invented.
- Inventory exposes personal gold, ring equip/unequip, binding provenance and upgrade level. Chest gold moves only into this character's wallet.
- All counter/NPC changes use separate art layers and retain an accessible central doorway lane.

## Release scope
This work is a source/native-QA checkpoint. It does not create another APK or alter the verified v0.10 release. Town residents, residential/stall polish and outer-area ambient creatures remain queued after this bounded tutorial/shops checkpoint.

## Required verification before publication
1. Legacy save migration, invalid-state rejection, one-time gold/gifts, bound instance ownership and full failure rollback.
2. Existing 12 outfit, controls, room/world collision, fortified gates and door-return regressions.
3. Actual doorway-envelope-to-guild-to-shops sequence through UI callbacks, reload and no premature combat completion.
4. Native 1280×720 and 844×390 dialogue, updated NPC/counter orientation, sword/body depth and quest/inventory captures.

## Source result
All 21 regression suites pass: 39708 checks, plus title geometry272 (total39980). New actual scene sequence67 checks; tutorial planner/dialogue885; transactional Save2682. Four sideways layouts pass native-engine headless reachability and player/counter/attendant ordering assertions. Native pixel review remains pending until the QA-only CI capture completes.
