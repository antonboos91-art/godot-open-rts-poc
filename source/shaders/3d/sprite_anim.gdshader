// Hochaufgeloeste Animations-Sprites (KI-Konzeptbilder, freigestellt), immer zur Kamera gedreht.
// Spiegelt bei Bedarf (flip) und malt einen Teamfarben-Ring unter die Fuesse.
shader_type spatial;
// Globale Helligkeit fuer unbeleuchtete Sprites (Stimmung, Tag/Nacht), siehe project.godot [shader_globals]
global uniform vec4 sprite_light;
render_mode unshaded, cull_disabled, shadows_disabled, skip_vertex_transform;

uniform sampler2D sheet : source_color, filter_linear;
uniform int frames = 32;
uniform int frame = 0;
uniform bool flip = false;
uniform bool ring = true;
uniform vec3 team_color : source_color = vec3(1.0, 0.0, 1.0);
uniform float construction = 1.0;
uniform float brightness = 1.0;
uniform float depth_bias = 3.0;

void vertex() {
	mat4 billboard = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]
	);
	VERTEX = (billboard * vec4(VERTEX, 1.0)).xyz;
	VERTEX.z += depth_bias;
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float u = flip ? 1.0 - UV.x : UV.x;
	vec4 c = texture(sheet, vec2((u + float(frame)) / float(frames), UV.y));
	// Teamfarben-Ring unter den Fuessen
	vec2 p = (UV - vec2(0.5, 0.93)) / vec2(0.30, 0.055);
	float ring_d = dot(p, p);
	bool ring_on = ring;
	if (c.a < 0.5) {
		if (ring_on && ring_d < 1.0 && ring_d > 0.45) {
			ALBEDO = team_color;
		} else {
			discard;
		}
	} else {
		ALBEDO = c.rgb * brightness;
		if (construction < 1.0) {
			float filled = step(1.0 - UV.y, construction);
			vec3 holo = vec3(0.2, 0.9, 1.0) * dot(c.rgb, vec3(0.33)) * 1.6;
			ALBEDO = mix(holo, c.rgb, filled);
			// leuchtende Scanlinie an der Baukante plus feine Hologramm-Zeilen
			float edge = 1.0 - smoothstep(0.0, 0.035, abs((1.0 - UV.y) - construction));
			ALBEDO += vec3(0.4, 0.9, 1.0) * edge * 1.5;
			ALBEDO *= 0.9 + 0.1 * sin(UV.y * 220.0 + TIME * 6.0) * (1.0 - filled);
		}
		ALBEDO *= sprite_light.rgb;
	}
}
