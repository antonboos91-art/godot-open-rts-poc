// Ziehende Nebelschwaden ueber der Karte: animiertes Rauschen, vom Wind verschoben,
// weich ausgeblendet wo der Nebel Boden oder Einheiten schneidet.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

uniform vec4 mist_color : source_color = vec4(0.34, 0.35, 0.34, 1.0);
uniform float density = 0.45;
uniform vec2 wind = vec2(0.9, 0.35);
uniform float scale = 0.035;
uniform float softness = 1.6;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear;

varying vec3 world_pos;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * scale;
	float t = TIME;
	float n = texture(noise_tex, p + wind * t * scale).r;
	float n2 = texture(noise_tex, p * 2.3 - wind.yx * t * scale * 1.7 + vec2(0.37, 0.61)).r;
	float m = smoothstep(0.42, 0.8, n * 0.7 + n2 * 0.45);
	// weiche Kante an Geometrie (Tiefenvergleich)
	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	vec4 world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	world.xyz /= world.w;

	float soft = clamp(distance(world.xyz, CAMERA_POSITION_WORLD) - distance(world_pos, CAMERA_POSITION_WORLD), 0.0, softness) / softness;
	ALBEDO = mist_color.rgb;
	ALPHA = m * density * soft;
}
