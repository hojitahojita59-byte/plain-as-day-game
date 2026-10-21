// Cinta de agua: brillo aditivo que avanza (avance 0-1) con un pulso que corre.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 color : source_color = vec4(0.55, 0.86, 1.0, 1.0);
uniform float avance = 1.0;
uniform float energia = 1.4;
// Largo en metros: el pulso va a la misma velocidad en cintas cortas y largas.
uniform float largo = 100.0;

void fragment() {
	if (UV.x > avance) {
		discard;
	}
	float borde = 1.0 - abs(UV.y * 2.0 - 1.0);
	float cabeza = smoothstep(avance - 6.0 / largo, avance, UV.x) * step(avance, 0.999);
	float pulso = 0.7 + 0.3 * sin(UV.x * largo * 0.35 - TIME * 4.0);
	ALBEDO = color.rgb * energia * (pulso + cabeza * 2.5);
	ALPHA = color.a * smoothstep(0.0, 0.45, borde);
}
