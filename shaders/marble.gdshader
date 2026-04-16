shader_type spatial;

void fragment() {
	// Diagonal stripes — visible when rolling in any direction
	float t      = fract((UV.x + UV.y) * 4.0);
	float stripe = step(0.5, t);
	ALBEDO    = mix(vec3(0.85, 0.06, 0.06), vec3(0.08, 0.72, 0.12), stripe);
	ROUGHNESS = 0.25;
	METALLIC  = 0.12;
	SPECULAR  = 0.65;
}
