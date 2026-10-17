shader_type canvas_item;
uniform vec4 hair_color : source_color = vec4(0.45, 0.31, 0.23, 1.0);
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float value = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	// Neutral generated hair retains shaded outlines and luminous strand detail.
	vec3 shade = hair_color.rgb * mix(0.18, 1.30, value);
	float highlight = smoothstep(0.60, 1.0, value) * 0.40;
	COLOR = vec4(mix(shade, vec3(1.0), highlight), source.a);
}
