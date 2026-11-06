shader_type canvas_item;

uniform float blood_alpha : hint_range(0.0, 1.0) = 0.8;
uniform vec4 blood_color : source_color = vec4(0.5, 0.0, 0.0, 1.0);
uniform float vignette_factor : hint_range(0.0, 2.0) = 1.0;

// Simple 2D pseudo-random hash
float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// 2D Value Noise
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal Brownian Motion for organic blood splatter noise
float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amplitude * noise(p);
		p *= 2.0;
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 uv = UV;
	
	// Noise pattern for organic blood splatters
	float n = fbm(uv * 6.0);
	
	// Radial/corner factor so blood splatters concentrate near screen borders/corners
	vec2 dist_from_center = abs(uv - vec2(0.5));
	float edge_factor = length(dist_from_center) * vignette_factor;
	
	// Combine noise with edge concentration
	float blood_pattern = smoothstep(0.25, 0.65, n * (edge_factor + 0.5));
	
	// Deep red color tone variation
	vec3 col = mix(blood_color.rgb * 0.5, blood_color.rgb, n);
	
	COLOR = vec4(col, blood_pattern * blood_alpha * blood_color.a);
}
