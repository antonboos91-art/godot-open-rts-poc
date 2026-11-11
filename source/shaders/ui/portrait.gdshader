// Portraet auf einem Monitor: leichte Scanlines, Rand-Vignette, gruenlicher Schimmer, sanftes Flimmern.
shader_type canvas_item;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float scan = 0.88 + 0.12 * sin(UV.y * 420.0 + TIME * 4.0);
	vec2 d = UV - 0.5;
	float vig = smoothstep(0.75, 0.25, length(d * vec2(1.0, 0.9)));
	float flick = 0.97 + 0.03 * sin(TIME * 23.0);
	vec3 rgb = c.rgb * scan * vig * flick;
	rgb = mix(rgb, rgb * vec3(0.85, 1.08, 0.9), 0.35);
	COLOR = vec4(rgb, c.a);
}
