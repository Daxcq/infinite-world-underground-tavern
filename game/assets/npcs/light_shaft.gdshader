shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

void fragment() {
	ALBEDO = vec3(0.62, 0.52, 0.37);
	ALPHA = 0.035 * pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0)
		* smoothstep(0.0, 0.12, UV.y) * (1.0 - smoothstep(0.75, 1.0, UV.y));
}
