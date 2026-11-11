// Fahrzeuge (3D) im Dark-Reign-Look: abgekaempft und dreckig.
// Grundfarbe/Metall/Rauheit/Leuchten kommen aus dem Original-Material des Modells.
// Darueber: ausgeblichener, dunklerer Lack, fleckiger Staub und Russ, Rostflecken,
// Schlamm unten an Wanne und Ketten, mattere Oberflaeche. Muster liegt im Modellraum (faehrt mit).
shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform sampler2D base_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_tex = false;
uniform float metallic = 0.3;
uniform float roughness = 0.5;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform float wear = 1.0;       // 0 = neu, 1 = abgekaempft
uniform float mud_height = 0.45;  // Modellhoehe (m), bis zu der Schlamm reicht

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

float tri(vec3 p, vec3 n, float s) {
	vec3 w = abs(n);
	w /= (w.x + w.y + w.z);
	return texture(noise, p.yz * s).r * w.x + texture(noise, p.xz * s).r * w.y + texture(noise, p.xy * s).r * w.z;
}

void fragment() {
	vec3 col = base_color.rgb;
	if (use_tex) {
		col *= texture(base_tex, UV).rgb;
	}
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(lum), 0.22 * wear) * mix(1.0, 0.8, wear);
	float big = tri(lp, ln, 0.9);
	float fine = tri(lp, ln, 3.7);
	// Staub/Russ
	float dust = smoothstep(0.45, 0.75, big * 0.7 + fine * 0.4) * 0.42 * wear;
	col = mix(col, vec3(0.085, 0.075, 0.062), dust);
	// Rost in Flecken
	float rust = smoothstep(0.72, 0.86, fine * 0.8 + big * 0.35) * 0.3 * wear;
	col = mix(col, vec3(0.2, 0.085, 0.035), rust);
	// Schlamm unten
	float mud = (1.0 - smoothstep(mud_height * 0.35, mud_height, lp.y)) * smoothstep(0.25, 0.6, big + 0.15) * wear;
	col = mix(col, vec3(0.1, 0.08, 0.055), clamp(mud, 0.0, 0.7));
	ALBEDO = col;
	METALLIC = metallic * (1.0 - dust * 0.6 - mud * 0.8);
	ROUGHNESS = clamp(max(roughness, 0.6) + dust * 0.25 + mud * 0.3, 0.0, 1.0);
	EMISSION = emission.rgb * emission_energy;
}
