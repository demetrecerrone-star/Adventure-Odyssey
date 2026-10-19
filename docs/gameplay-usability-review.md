# Gameplay usability regression review

October 19, 2026; local source changes only. No new APK, save-schema or balance change.

## Reproduced and corrected
1. An equipment save failure closed the item popup. The old weapon and disk save were safe, but retry required finding the item again. Errors now remain visible inside the open popup, with the existing action ready to retry. Successful swaps still return to the refreshed inventory.
2. An open item popup retained desktop dimensions after resizing to a landscape phone. Its frame, header and scroll area now reflow without changing selection or inventory.
3. The preview's equipped hidden-stick sprite rendered over popup text because its sprite layer was above the modal shade. Item popups now sit above all preview weapon layers. Artwork and damage are unchanged.
4. Quest-action save errors were below the dialogue fold. They now appear at the top in a distinct error color, while the pending choice is re-enabled. Accept/defer/resume behavior and rewards are unchanged.
5. Repeated conversation rebuilds accumulated stale touch-control references. Rebuilds now release touch ownership and discard old choice controls before adding new ones.

## Evidence
The initial new regression reported five failures across both handed layouts and the dialogue error view. A separate repeated-conversation check reproduced stale-control accumulation. After correction,39 headless checks passed, including actual injected write failure, byte-identical save rollback, retry, full reload, popup resizing and50 conversation rebuilds. Native phone views were inspected for both handed layouts; no floating weapon remains over text.

A final aggregate run is recorded in the morning review separately; focused results here are not a substitute for that run. Secure Remember me still requires actual Android Keystore/JNI/restart/tamper and latency verification in a later approved build.
