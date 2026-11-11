// Leuchtende Rohstoff-Kristalle: dunkles Glas mit gruenem Innenleuchten, hellere Kanten (Fresnel),
// langsames Pulsieren und ein heller Schimmer, der durch die Kristalle wandert. HDR fuer Bloom.
shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

uniform vec4 glow_color : source_color = vec4(0.25, 1.0, 0.45, 1.0);
uniform float glow = 2.2;
uniform float phase = 0.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float pulse = 0.75 + 0.25 * sin(TIME * 1.6 + phase);
	float shimmer = smoothstep(0.85, 1.0, sin(local_pos.y * 4.0 - TIME * 2.2 + phase * 3.0));
	float depth = clamp(local_pos.y * 0.6 + 0.3, 0.0, 1.0);
	ALBEDO = glow_color.rgb * 0.12;
	METALLIC = 0.2;
	ROUGHNESS = 0.12;
	SPECULAR = 0.8;
	EMISSION = glow_color.rgb * glow * (0.35 + depth * 0.5 + fres * 1.4 + shimmer * 0.9) * pulse;
}
