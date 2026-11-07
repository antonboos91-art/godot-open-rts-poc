// Pixel-Art-Sprite, das immer zur Kamera zeigt.
// Magenta-Pixel (r == b, g == 0) werden durch die Teamfarbe ersetzt.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, skip_vertex_transform;

uniform sampler2D sheet : source_color, filter_nearest;
uniform int frames = 8;
uniform int frame = 0;
uniform vec3 team_color : source_color = vec3(1.0, 0.0, 1.0);
uniform float construction = 1.0;  // < 1: im Bau (Hologramm-Look)
uniform float brightness = 1.0;
// Schiebt das Sprite Richtung Kamera, damit es nicht im Boden versinkt
uniform float depth_bias = 3.0;

void vertex() {
	// Volle Billboard-Ausrichtung, Größe kommt aus dem Mesh
	mat4 billboard = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]
	);
	VERTEX = (billboard * vec4(VERTEX, 1.0)).xyz;
	VERTEX.z += depth_bias;
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	vec2 uv = vec2((UV.x + float(frame)) / float(frames), UV.y);
	vec4 c = texture(sheet, uv);
	if (c.a < 0.5) {
		discard;
	}
	if (abs(c.r - c.b) < 0.02 && c.g < 0.02 && c.r > 0.05) {
		c.rgb = team_color * (c.r * 1.1);
	}
	if (construction < 1.0) {
		float scan = step(0.5, fract(FRAGCOORD.y * 0.25 + TIME * 2.0));
		float filled = step(1.0 - UV.y, construction);
		vec3 holo = vec3(0.2, 0.9, 1.0) * dot(c.rgb, vec3(0.33)) * 1.6;
		c.rgb = mix(holo * (0.6 + 0.4 * scan), c.rgb, filled);
	}
	ALBEDO = c.rgb * brightness;
}
