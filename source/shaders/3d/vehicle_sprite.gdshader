// Vorgerenderte Fahrzeug-Sprites (Factorio-Prinzip): Spalten = Blickrichtungen, Zeilen = Animationsframes.
// Das Quad zeigt immer zur Kamera; weiche Alphakante und gerenderter Schatten bleiben erhalten.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, skip_vertex_transform, depth_prepass_alpha, blend_mix;

uniform sampler2D sheet : source_color, filter_linear_mipmap;
uniform int columns = 64;
uniform int rows = 1;
uniform int column = 0;
uniform int row = 0;
uniform float depth_bias = 3.0;
uniform float brightness = 1.2;
uniform float flash = 0.0;  // kurzes Aufhellen bei Treffern

void vertex() {
	mat4 billboard = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]
	);
	VERTEX = (billboard * vec4(VERTEX, 1.0)).xyz;
	VERTEX.z += depth_bias;
}

void fragment() {
	vec2 uv = vec2((UV.x + float(column)) / float(columns), (UV.y + float(row)) / float(rows));
	vec4 c = texture(sheet, uv);
	if (c.a < 0.02) {
		discard;
	}
	vec3 rgb = c.rgb / max(c.a, 0.001);
	// Der gerenderte Bodenschatten (schwarz, teiltransparent) wird weich eingeblendet statt als schwarzer Fleck
	bool is_shadow = (rgb.r + rgb.g + rgb.b) < 0.09 && c.a < 0.95;
	ALBEDO = rgb * brightness + vec3(flash);
	if (is_shadow) {
		ALPHA = c.a * 0.45;
	} else if (c.a < 0.5) {
		discard;
	} else {
		ALPHA = 1.0;
	}
}
