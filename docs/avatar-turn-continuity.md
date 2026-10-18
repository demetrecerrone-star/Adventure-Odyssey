# Continuous stride while steering

Walking direction changes retain the current fractional animation phase instead of restarting the first drawing. True stops and restarts still reset naturally. Mixed fallback cycles map normalized phase when their frame counts or rates differ.

All approved source drawings, customization layers, six-frame 9 fps cadence, distance-driven analog playback and 155 px/s movement remain unchanged. This removes a renderer-induced turning snap; it does not redraw the gait or claim perfect foot planting.

The regression covers all twelve outfits, every facing transition at each phase, equipped and unequipped states, fractional timing, rapid steering, stopping and mixed fallback cycles. The native comparison replays the old reset behavior beside the new renderer for both bases and all six classes. Native visual review remains required before acceptance.
