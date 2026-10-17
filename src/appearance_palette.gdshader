shader_type canvas_item;
render_mode unshaded;
uniform sampler2D appearance_mask : filter_linear, repeat_disable;
uniform vec4 skin_color : source_color = vec4(0.788, 0.565, 0.396, 1.0);
uniform vec4 eye_color : source_color = vec4(0.40, 0.22, 0.12, 1.0);
void fragment() {
 vec4 original = texture(TEXTURE, UV);
 vec2 mask = texture(appearance_mask, UV).rg;
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
