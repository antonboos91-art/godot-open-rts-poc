// Prozeduraler Boden: Gras, trockenes Gras, Erde und Sandflecken mit weichen Uebergaengen,
// feiner Kachel-Struktur und dunklem Waldboden am Kartenrand.
shader_type spatial;
render_mode cull_back, unshaded;

uniform vec2 map_size = vec2(50.0, 50.0);
uniform vec3 grass_color : source_color = vec3(0.16, 0.50, 0.08);
uniform vec3 grass_dry_color : source_color = vec3(0.34, 0.50, 0.12);
uniform vec3 dirt_color : source_color = vec3(0.36, 0.26, 0.16);
uniform vec3 sand_color : source_color = vec3(0.62, 0.54, 0.36);
uniform vec3 border_color : source_color = vec3(0.04, 0.08, 0.04);
uniform float seed = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21) + seed);
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + 11.7;
		a *= 0.5;
	}
	return v;
}

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float large = fbm(p * 0.14);
	float medium = fbm(p * 0.35 + 5.0);
	float fine = fbm(p * 1.6);

	vec3 col = mix(grass_color, grass_dry_color, smoothstep(0.55, 0.85, medium));
	// Erdflecken
	col = mix(col, dirt_color, smoothstep(0.66, 0.82, large) * 0.8);
	// Sandflecken (seltener)
	col = mix(col, sand_color, smoothstep(0.78, 0.88, fbm(p * 0.17 + 31.0)) * 0.8);
	// Grashalm-Struktur
	col *= 0.82 + 0.36 * fine;
	// feine Kacheln, 1 Weltmeter, leichte Helligkeitsvariation je Kachel
	vec2 cell = floor(p);
	col *= 0.94 + 0.12 * hash(cell);
	vec2 g = abs(fract(p) - 0.5);
	col *= 1.0 - 0.05 * smoothstep(0.44, 0.5, max(g.x, g.y));

	// Kartenrand: dunkler Waldboden
	float edge = min(min(p.x, map_size.x - p.x), min(p.y, map_size.y - p.y));
	col = mix(border_color, col, smoothstep(-2.0, 1.5, edge));

	ALBEDO = pow(col, vec3(2.2));
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}
