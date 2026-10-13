shader_type canvas_item;
render_mode unshaded;
uniform float gust = 0.0;
uniform float phase = 0.0;

void fragment() {
	vec2 uv = UV;
	// Only leafy crowns move. Ground, shop furniture and trunks stay still.
	float left_crown = 1.0 - smoothstep(0.10, 0.19, length((uv - vec2(0.13, 0.49)) * vec2(0.8, 1.0)));
	left_crown *= 1.0 - smoothstep(0.55, 0.63, uv.y);
	float upper_left = 1.0 - smoothstep(0.05, 0.13, length(uv - vec2(0.15, 0.04)));
	float upper_right = 1.0 - smoothstep(0.05, 0.12, length(uv - vec2(0.93, 0.10)));
	float mask = max(left_crown, max(upper_left, upper_right));
	vec2 bend = vec2(sin(phase * 1.7 + uv.y * 22.0), cos(phase * 1.3 + uv.x * 27.0) * 0.45);
	uv += bend * vec2(0.0024, 0.0017) * gust * mask;
	COLOR = texture(TEXTURE, uv);
}
