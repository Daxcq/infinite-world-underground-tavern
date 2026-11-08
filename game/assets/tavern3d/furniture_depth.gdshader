shader_type spatial;
render_mode unshaded, depth_draw_always, cull_disabled, shadows_disabled;

void fragment() {
	// Furniture is painted in the original background. Only its depth is needed.
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
}
