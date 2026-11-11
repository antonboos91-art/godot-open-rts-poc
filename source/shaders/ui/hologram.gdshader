// Gruen leuchtendes Hologramm-Symbol im StarCraft-Stil: Helligkeit des Bildes wird zu Gruen,
// Umrisse leuchten heller, feine Scanlines. health (0..1) faerbt bei Schaden Richtung Gelb/Rot.
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.25, 1.0, 0.45, 1.0);
uniform float health = 1.0;
uniform float glow = 1.6;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float lum = dot(c.rgb, vec3(0.3, 0.55, 0.15));
	// Kante: Alpha-Unterschied zu Nachbarpixeln
	vec2 px = TEXTURE_PIXEL_SIZE * 1.5;
	float a_n = texture(TEXTURE, UV + vec2(px.x, 0)).a + texture(TEXTURE, UV - vec2(px.x, 0)).a
		+ texture(TEXTURE, UV + vec2(0, px.y)).a + texture(TEXTURE, UV - vec2(0, px.y)).a;
	float edge = clamp(c.a * 4.0 - a_n, 0.0, 1.0) + clamp(a_n * 0.25 - c.a, 0.0, 1.0) * 0.6;
	vec3 col = mix(vec3(1.0, 0.25, 0.15), mix(vec3(1.0, 0.85, 0.2), tint.rgb, smoothstep(0.35, 0.7, health)), smoothstep(0.1, 0.35, health));
	float scan = 0.85 + 0.15 * sin(SCREEN_UV.y * 900.0);
	vec3 rgb = col * (0.25 + lum * 1.1) * scan + col * edge * glow;
	float a = max(c.a * 0.9, edge * 0.8);
	COLOR = vec4(rgb, a);
}
