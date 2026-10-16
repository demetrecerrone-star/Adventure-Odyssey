# Adventure Odyssey — Sigils and Loot Validation (2026-10-16)

This note records a **tests-only GitHub Actions push** against current `main`.
The push workflow runs `inspect-source` and `validate-title`. The
`android-apk` job runs only on `workflow_dispatch`, not on a push.

## Regression coverage to verify

- `tests/monster_loot_test.gd`: ordinary slimes, wolves, goblins, and fungi
  never drop Sigils, including on forced winning RNG rolls.
- Oldstone guardian's Sigil reward is a **10% independent roll for five Sigils**,
  not a guaranteed drop. The same defeated boss must not award the same
  loot again.
- Regular monster rare equipment rolls remain independent of currency.
- `tests/sigils_currency_test.gd`: Sigil balance is separate from gold,
  survives saves, and older saves remain compatible.
- Free starter furniture remains free, and unreleased cosmetic art cannot
  deduct Sigils.
- Godot headless scene-test suite must complete without parser errors.

This document does not represent a passing result. Consult the GitHub
Actions run for the push to confirm the actual outcomes.
