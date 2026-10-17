# Directional hair catalog

Thirty independent image-generated hairstyles (15 male and 15 female), registered onto the existing bald body heads. Body and outfit artwork remains unchanged. The creator and mirror use stable `male_hair_01..15` / `female_hair_01..15` IDs and manifest names. Gender/base remains locked by the existing post-creation workflow.

## Runtime contract

`src/character_hair.gd` inserts `HairRear` before Body and `HairFront` after Armor. The palette shader is applied only to those hair sprites, with six selectable colors. Missing, wrong-gender or malformed entries hide hair only. Rendering tracks the body's actual animation, frame count and frame index. Only the active hair style remains cached.

Every style has four idle facings (down, left, right, up) and four eight-frame directional walking atlases, 256px square cells with foot origin (128,232). Each animation has separate rear and front hair textures. Walking applies the same ±0.9px head bob as the existing body gait; there is no independently authored hair-sway animation. Tied rear tails in front view are occluded by the body. Loose face-framing lengths remain foreground; rear-facing hair covers the back naturally.

## Production and preservation

Original transparent four-view sheets were created with built-in image generation, using the existing approved elevated three-quarter overhead body art as reference. Original sheets and exact prompts are retained in the separate production backup. Registration crops remove low-alpha background noise and stray cell-edge components, normalize only the hair pixels to neutral grayscale, and fit independently reviewed per-facing rectangles. The manifest records source hashes and registration bounds. No existing body/armor texture is regenerated, overwritten or tinted by this system.

## Verification

- `tests/hair_test.gd`: all 30 styles across six classes, both bases, idle directions, eight walking phases, color isolation, layer order and missing/malformed/wrong-base fail-closed behavior.
- `tests/hair_screenshot.gd`: twelve native contact sheets covering every style and facing in idle/walk, plus all six hair colors on both bases.
- `tests/appearance_test.gd`: existing skin/eye integration plus creator hair preview.

CPU composited artwork reviews are distinct from native shader/device verification. Android device performance and final integrated room occlusion should be reviewed in the APK.
