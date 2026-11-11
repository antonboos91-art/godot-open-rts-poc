// Energiestrahl (Laser/Phaser/Plasma) als zur Kamera gedrehtes Band zwischen zwei Weltpunkten:
// weicher Gauss-Verlauf statt harter Kante, heisser Kern der in die Volksfarbe uebergeht,
// fliessende Energie-Wellen entlang des Strahls, flackernde Breite, weiche Enden. Additiv + HDR fuer Bloom.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

uniform vec3 start = vec3(0.0);
uniform vec3 end = vec3(0.0, 0.0, -1.0);
uniform float width = 0.3;
uniform vec4 color : source_color = vec4(1.0, 0.3, 1.0, 1.0);
uniform float energy = 3.0;     // HDR-Helligkeit
uniform float intensity = 1.0;  // 0..1, zum Ausblenden
uniform float flicker = 0.25;   // Phaser: staerkeres Flackern
uniform float flow_speed = 18.0;
uniform float seed = 0.0;

varying float beam_len;

void vertex() {
	vec3 axis = end - start;
	beam_len = length(axis);
	vec3 dir = axis / max(beam_len, 0.0001);
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 mid = mix(start, end, UV.y);
	vec3 to_cam = normalize(cam - mid);
	// Orthokamera: Blickrichtung statt Kameraposition
	if (PROJECTION_MATRIX[3][3] > 0.5) {
		to_cam = normalize(INV_VIEW_MATRIX[2].xyz);
	}
	vec3 side = normalize(cross(dir, to_cam));
	float w = width * (1.0 + flicker * (sin(TIME * 47.0 + seed) * 0.5 + sin(TIME * 83.0 + seed * 2.0) * 0.5));
	vec3 world = mid + side * (UV.x - 0.5) * w;
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
}

void fragment() {
	float d = abs(UV.x - 0.5) * 2.0;
	float along = UV.y * beam_len;
	// fliessende Energie: mehrere gegeneinander laufende Wellen
	float t = TIME * flow_speed + seed;
	float waves = 0.55
		+ 0.25 * sin(along * 3.1 - t)
		+ 0.15 * sin(along * 7.7 - t * 1.6 + d * 4.0)
		+ 0.10 * sin(along * 13.0 + t * 0.7);
	float core = exp(-d * d * 55.0);
	float glow = exp(-d * d * 7.0) * waves;
	float halo = exp(-d * d * 2.2) * 0.25;
	// weiche Enden
	float ends = smoothstep(0.0, min(0.06, 0.4 / max(beam_len, 0.1)), UV.y) * smoothstep(1.0, 1.0 - min(0.04, 0.3 / max(beam_len, 0.1)), UV.y);
	vec3 hot = mix(color.rgb, vec3(1.0), 0.55);
	vec3 col = color.rgb * (glow + halo) + hot * core * 0.9;
	ALBEDO = col * energy * intensity * ends;
}
