shader_type spatial;
// Marcas del globo (aditivo). kind 0 = punto con halo, 1 = anillos sobre la superficie.

render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform int kind = 0;
uniform vec3 color : source_color = vec3(1.0, 0.80, 0.45);
// 0 = oculta (cara de atras del globo), 1 = visible.
uniform float fade : hint_range(0.0, 1.0) = 1.0;
// Destello al aparecer.
uniform float flash = 0.0;
// 1 = el halo late.
uniform float pulse = 0.0;
uniform float billboard = 1.0;
// Anillos: 1 = se repiten solos; 0 = un solo anillo que sigue a "progreso".
uniform float ring_loop = 0.0;
uniform float ring_speed = 0.42;
uniform float progreso : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	if (billboard > 0.5) {
		float s = length(MODEL_MATRIX[0].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	}
}

void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	float r = length(q);
	float beat = 0.5 + 0.5 * sin(TIME * 2.6);
	vec3 c = vec3(0.0);

	if (kind == 0) {
		float core = 1.0 - smoothstep(0.09, 0.16, r);
		float halo = exp(-r * r * 10.0) * (0.55 + 0.45 * beat * pulse);
		float burst = exp(-r * r * 2.5) * flash * 1.6;
		c = mix(color, vec3(1.0), 0.35) * core * 1.6 + color * (halo + burst);
	} else {
		float a = 0.0;
		for (int k = 0; k < 2; k++) {
			float ph = ring_loop > 0.5 ? fract(TIME * ring_speed + float(k) * 0.5) : (k == 0 ? progreso : 1.0);
			float w = 0.035 + 0.05 * ph;
			a += (1.0 - smoothstep(0.0, w, abs(r - (0.12 + 0.82 * ph)))) * (1.0 - ph) * (1.0 - ph);
		}
		c = color * a * 1.4;
	}

	c *= fade * (1.0 - smoothstep(0.92, 1.0, r));
	ALBEDO = c;
	ALPHA = 1.0;
}
