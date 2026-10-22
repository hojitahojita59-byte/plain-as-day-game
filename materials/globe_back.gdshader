shader_type spatial;
// Cara de atras del globo: reticula y costas tenues, vistas a traves de la de delante.

render_mode blend_add, cull_front, unshaded, depth_draw_never, shadows_disabled;

uniform sampler2D map : filter_linear_mipmap, repeat_enable;
uniform vec3 line_color : source_color = vec3(0.45, 0.62, 0.95);
uniform float strength : hint_range(0.0, 1.0) = 0.30;
uniform float meridians = 24.0;
uniform float parallels = 12.0;

float grid_line(float v, float n) {
	float f = fract(v * n);
	float d = min(f, 1.0 - f);
	return 1.0 - smoothstep(0.0, fwidth(v * n) * 1.1, d);
}

void fragment() {
	vec4 m = texture(map, vec2(fract(UV.x + 0.5), UV.y));
	float pole = smoothstep(0.02, 0.10, min(UV.y, 1.0 - UV.y));
	float g = max(grid_line(UV.x, meridians) * pole, grid_line(UV.y, parallels));
	ALBEDO = line_color * (g * 0.45 + m.g * 0.9) * strength;
	ALPHA = 1.0;
}
