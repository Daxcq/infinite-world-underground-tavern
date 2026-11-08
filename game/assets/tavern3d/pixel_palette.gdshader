shader_type canvas_item;
render_mode unshaded;

uniform sampler2D world_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	vec3 color = texture(world_texture, SCREEN_UV).rgb;
	// Broad color clusters preserve the warm wood, green walls and dark coats.
	color = floor(color * 24.0 + 0.5) / 24.0;
	COLOR = vec4(color, 1.0);
}
