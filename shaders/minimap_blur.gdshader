shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float blur_radius : hint_range(0.0, 5.0) = 1.8;

void fragment() {
	vec4 color = vec4(0.0);
	int samples = 0;
	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			vec2 offset = vec2(float(x), float(y)) * blur_radius / VIEWPORT_SIZE;
			color += texture(SCREEN_TEXTURE, SCREEN_UV + offset);
			samples++;
		}
	}
	COLOR = color / float(samples);
}
