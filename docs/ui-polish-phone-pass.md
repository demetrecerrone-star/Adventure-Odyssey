# Phone UI polish checkpoint

Reviewed QA352 native phone HUD, menu, Stats, Inventory, dialogue and shop views. This bounded pass preserves the ivory/gold visual language, all saves and all progression/purchase rules.

- The short-screen hamburger panel uses a two-column grid so all six destinations, including Settings and Save & title, are visible without scrolling. Targets remain at least 44 px. Taller screens retain a single column.
- The quest tracker has two wrapped lines and a wider reading area. The initial doorstep objective is no longer cut off mid-destination. Long objectives can still open the existing Quest Log for full details. Existing safe-area, control-cluster and handedness separation tests apply.
- Inventory now labels the wallet plainly rather than repeating Your bag twice. Saved portrait, owned counts, binding and explicit equipment actions are unchanged.
- Shop offers reuse the same item icons as Inventory, show actual bag counts and clear selection. Selecting an offer reveals quantity/review controls on phones. Review and confirm remain separate; no purchase occurs merely from browsing.

Stats and dialogue were inspected and retained: the Stats confirmation controls are already fixed and visible, Luck remains XP-only, and dialogue text/Leave controls fit the tested phone viewport. Scrollbars retain their deliberate touch-friendly width.

Native screenshots are required after source tests. This is a QA-only source checkpoint, not an APK or hardware Android performance claim.
