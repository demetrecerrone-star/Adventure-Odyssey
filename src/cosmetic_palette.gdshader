shader_type canvas_item;
render_mode unshaded;
uniform vec4 pigment : source_color = vec4(0.38, 0.53, 0.75, 1.0);
uniform bool blanket_only = false;
uniform float dye_strength = 1.0;
uniform float head_lift = 0.0;
uniform float sheet_frames = 4.0;
varying vec4 canvas_tint;
void vertex() { canvas_tint = COLOR; }
void fragment() {
 vec2 sample_uv = UV;
 float cell_x = fract(UV.x * sheet_frames) * 256.0;
 float head_region = 1.0 - smoothstep(32.0, 50.0, abs(cell_x - 128.0));
 float neck_transition = 1.0 - smoothstep(85.0, 108.0, UV.y * 256.0);
 sample_uv.y += head_lift * head_region * neck_transition / 256.0;
 vec4 source = texture(TEXTURE, sample_uv);
 float hi = max(source.r, max(source.g,source.b));
 float lo = min(source.r, min(source.g,source.b));
 float saturation = (hi-lo) / max(hi,0.001);
 float mask = smoothstep(0.10,0.27,saturation);
 if (blanket_only) {
  // Registered 1536x1024 bed canvas: isolate olive bedding by hue and bounds.
  // Wood has a larger red/green ratio; the cream pillow lies above this region.
  mask = (1.0-smoothstep(1.22,1.34,source.r/max(source.g,0.001)))
    * smoothstep(1.13,1.28,source.g/max(source.b,0.001))
    * step(0.390,UV.y) * (1.0-step(0.561,UV.y))
    * step(0.135,UV.x) * (1.0-step(0.307,UV.x));
 }
 float value = dot(source.rgb,vec3(0.299,0.587,0.114));
 vec3 dyed = clamp(pigment.rgb * (value/0.48),vec3(0.0),vec3(1.0));
 // Preserve highlights, shading, original alpha and neutral metal accents.
 COLOR = vec4(mix(source.rgb,dyed,mask*dye_strength),source.a) * canvas_tint;
}
