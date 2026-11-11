// Natur-Sprite (Baum, Busch, Fels) als beleuchtete Billboard-Flaeche, die sich im Wind wiegt.
// Wird von Einheiten-Lichtern und der Sonne beleuchtet.
shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha, skip_vertex_transform;

uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic;
uniform float sway = 0.0;  // 0 = starr (Felsen), 1 = Baum

uniform float brightness = 0.85;
uniform vec2 wind = vec2(0.9, 0.35);

void vertex() {
	// Y-Billboard: Flaeche zur Kamera drehen, aufrecht bleiben
	vec3 cam_right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 origin = MODEL_MATRIX[3].xyz;
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	float h = max(VERTEX.y, 0.0);
	float phase = origin.x * 0.37 + origin.z * 0.21;
	float gust = sin(TIME * 1.3 + phase) * 0.6 + sin(TIME * 2.9 + phase * 1.7) * 0.25;
	vec3 offset = vec3(wind.x, 0.0, wind.y) * gust * sway * h * h * 0.02;
	vec3 world = origin + cam_right * VERTEX.x * sx + vec3(0.0, VERTEX.y * sy, 0.0) + offset;
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < 0.4) {
		discard;
	}
	ALBEDO = c.rgb * brightness;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
	// etwas Eigenlicht, damit die Silhouette nachts nicht komplett verschwindet
	EMISSION = c.rgb * 0.06;
}
