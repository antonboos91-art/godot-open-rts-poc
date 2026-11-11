// Boden aus kachelbaren Foto-Texturen (tools/comfyui/gen_ground.py + tools/make_ground_textures.py):
// Gras als Grundlage, trockenes Gras, Erd-, Fels-, Sand- und Schlammflecken mit weichen Uebergaengen.
// Beleuchtet (Sonne, Schatten, SSAO) mit Normal-Maps; Kachel-Wiederholung wird durch zwei
// gegeneinander gedrehte Massstaebe und Helligkeitsrauschen versteckt. Dunkler Waldboden am Kartenrand.
shader_type spatial;
render_mode cull_back;

uniform vec2 map_size = vec2(50.0, 50.0);
uniform float seed = 0.0;
uniform float tile_size = 7.0;  // Weltmeter je Texturkachel
uniform float normal_strength = 0.9;
uniform vec3 border_color : source_color = vec3(0.04, 0.07, 0.04);

uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D drygrass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D drygrass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

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

// Zwei Abtastungen (unterschiedlicher Massstab, gedreht) gegen sichtbare Kachel-Wiederholung
vec4 sample2(sampler2D tex, vec2 uv_a, vec2 uv_b, float k) {
	return mix(texture(tex, uv_a), texture(tex, uv_b), k);
}

void fragment() {
	vec2 p = world_pos.xz;
	vec2 uv_a = p / tile_size;
	mat2 rot = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
	vec2 uv_b = rot * p / (tile_size * 2.3) + vec2(0.37, 0.71);
	float k = smoothstep(0.35, 0.65, fbm(p * 0.09 + 3.0));

	float large = fbm(p * 0.07);
	float medium = fbm(p * 0.16 + 5.0);
	float w_dry = smoothstep(0.5, 0.75, medium);
	float w_dirt = smoothstep(0.6, 0.78, large) * 0.95;
	float w_rock = smoothstep(0.72, 0.85, fbm(p * 0.11 + 17.0));
	float w_sand = smoothstep(0.76, 0.88, fbm(p * 0.08 + 31.0));
	float w_mud = smoothstep(0.8, 0.9, fbm(p * 0.13 + 47.0)) * 0.9;

	vec3 col = sample2(grass_albedo, uv_a, uv_b, k).rgb;
	vec3 nrm = sample2(grass_normal, uv_a, uv_b, k).rgb;
	col = mix(col, sample2(drygrass_albedo, uv_a, uv_b, k).rgb, w_dry);
	nrm = mix(nrm, sample2(drygrass_normal, uv_a, uv_b, k).rgb, w_dry);
	col = mix(col, sample2(dirt_albedo, uv_a, uv_b, k).rgb, w_dirt);
	nrm = mix(nrm, sample2(dirt_normal, uv_a, uv_b, k).rgb, w_dirt);
	col = mix(col, sample2(sand_albedo, uv_a, uv_b, k).rgb, w_sand);
	nrm = mix(nrm, sample2(sand_normal, uv_a, uv_b, k).rgb, w_sand);
	col = mix(col, sample2(rock_albedo, uv_a, uv_b, k).rgb, w_rock);
	nrm = mix(nrm, sample2(rock_normal, uv_a, uv_b, k).rgb, w_rock);
	col = mix(col, sample2(mud_albedo, uv_a, uv_b, k).rgb, w_mud);
	nrm = mix(nrm, sample2(mud_normal, uv_a, uv_b, k).rgb, w_mud);

	// grossflaechige Helligkeitsvariation
	col *= 0.85 + 0.3 * fbm(p * 0.04 + 9.0);

	// Kartenrand: dunkler Waldboden
	float edge = min(min(p.x, map_size.x - p.x), min(p.y, map_size.y - p.y));
	col = mix(col * border_color * 12.0, col, smoothstep(-6.0, 1.0, edge));

	ALBEDO = col;
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = normal_strength;
	ROUGHNESS = mix(0.95, 0.75, w_mud);
	METALLIC = 0.0;
	SPECULAR = 0.3;
}
