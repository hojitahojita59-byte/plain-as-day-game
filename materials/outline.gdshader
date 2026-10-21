shader_type spatial;
// Contorno por casco invertido (material_overlay).

render_mode cull_front, unshaded, shadows_disabled, depth_draw_never;

uniform float thickness : hint_range(0.0, 0.15) = 0.02;
uniform vec4 line_color : source_color = vec4(0.04, 0.04, 0.05, 1.0);

void vertex() {
	VERTEX += normalize(NORMAL) * thickness;
}

void fragment() {
	ALBEDO = line_color.rgb;
}
