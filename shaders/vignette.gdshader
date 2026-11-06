shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv);
	
	// Radial falloff: 0 at center, darkens towards screen edges
	float vignette = smoothstep(0.1, 0.75, dist * (intensity * 1.5 + 0.5));
	float alpha = clamp(vignette * intensity * color.a, 0.0, 1.0);
	
	COLOR = vec4(color.rgb, alpha);
}
