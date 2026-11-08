// Laufende Panzerkette: Kettenglieder als Streifen entlang UV.x, "offset" verschiebt sie beim Fahren.
shader_type spatial;

uniform float offset = 0.0;
uniform float links = 70.0;
uniform vec3 metal : source_color = vec3(0.09, 0.09, 0.1);
uniform vec3 edge : source_color = vec3(0.32, 0.31, 0.3);

void fragment() {
	float u = fract((UV.x + offset) * links);
	float plate = smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.82, 0.92, u));
	float pin = 1.0 - smoothstep(0.0, 0.05, abs(UV.y - 0.5) - 0.32);
	vec3 c = mix(edge, metal, plate);
	c = mix(c, edge * 1.3, pin * (1.0 - plate) * 0.6);
	ALBEDO = c;
	METALLIC = 0.85;
	ROUGHNESS = mix(0.35, 0.7, plate);
}
