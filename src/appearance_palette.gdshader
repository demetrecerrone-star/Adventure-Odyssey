shader_type canvas_item;
render_mode unshaded;
uniform sampler2D appearance_mask : filter_linear, repeat_disable;
uniform vec4 skin_color : source_color = vec4(0.788, 0.565, 0.396, 1.0);
uniform vec4 eye_color : source_color = vec4(0.40, 0.22, 0.12, 1.0);
// Small, local neck extension: shoulders, hands and feet keep their registration.
// One horizontal sheet row is always 256 px; x is local to the current cell.
uniform float head_lift = 0.0;
uniform float sheet_frames = 4.0;
void fragment() {
 vec2 sample_uv = UV;
 float cell_x = fract(UV.x * sheet_frames) * 256.0;
 float head_region = 1.0 - smoothstep(32.0, 50.0, abs(cell_x - 128.0));
 float neck_transition = 1.0 - smoothstep(85.0, 108.0, UV.y * 256.0);
 sample_uv.y += head_lift * head_region * neck_transition / 256.0;
 vec4 original = texture(TEXTURE, sample_uv);
 vec2 mask = texture(appearance_mask, sample_uv).rg;
 // Preserve the source value variation, highlights and alpha; only isolated
 // body pigments change. Armor is a separate Sprite2D without this material.
 float value = dot(original.rgb, vec3(0.299, 0.587, 0.114));
 vec3 skin = skin_color.rgb * (value / 0.69);
 skin = mix(skin, vec3(1.0), max(value - 0.82, 0.0) * 1.8);
 vec3 eyes = eye_color.rgb * (0.45 + value * 1.9);
 vec3 result = mix(original.rgb, clamp(skin, 0.0, 1.0), mask.r);
 result = mix(result, clamp(eyes, 0.0, 1.0), mask.g);
 COLOR = vec4(result, original.a);
}
