# Larger actions and six core attributes

User feedback requests larger attack/skill buttons, a separate Use position, and Luck alongside the original five base stats.

Attack grows from76px to96px; all three skills grow from46px to64px. Contextual Use/Interact has its own200×52px centered lane above vitals rather than sharing the combat arc. The combat arc and joystick continue to swap for left-handed controls; interaction remains central. Safe-area bounds, long captions, modal clearing and secondary-finger handling are covered.

Stats now group STR Strength, AGI Agility, VIT Vitality, INT Intelligence, WIS Wisdom and LUK Luck together. All six are visible without scrolling at844×390. Attack power stays in a separate derived-combat section. Values read 'Not yet configured'. No numeric stat model exists in the current v7 save, so this presentation correction does not migrate or write saves. Historical pre-rebuild v0.3 set five stats to10, but those archived defaults are explicitly superseded, and no Luck number was defined. No starting values or effects are invented.

Native phone/right-handed/left-handed and Stats screenshots are required before visual signoff. No APK is triggered by this QA-only change.

Local final regression: 26 suites, 41,708 checks, zero failures. HUD1,455, menu377 and integrated HUD4,316 checks include all six visible core rows and preserved control ownership. Save schema remainsv7.
