shader_type spatial;
// Atmosfera del globo: cuadro de cara a la camara; mide la distancia del rayo al centro.

render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 color : source_color = vec3(0.32, 0.58, 1.0);
uniform float radius = 2.1;
uniform float strength : hint_range(0.0, 2.0) = 0.48;
// Cuanto se aleja el halo del borde.
uniform float falloff = 15.0;

varying vec3 w_pos;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	w_pos = (INV_VIEW_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0))).xyz;
}

void fragment() {
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 d = normalize(w_pos - cam);
	vec3 oc = NODE_POSITION_WORLD - cam;
	float b = length(oc - d * dot(oc, d));
	float x = b / radius;
	float outside = exp(-max(x - 1.0, 0.0) * falloff) * step(1.0, x);
	float inside = pow(clamp(x, 0.0, 1.0), 12.0) * 0.35 * (1.0 - step(1.0, x));
	ALBEDO = color;
	ALPHA = clamp((outside + inside) * strength, 0.0, 1.0);
}
