shader_type spatial;
// Insignia de las marcas "?": disco oscuro con borde claro, de cara a la camara.

render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 fill_color : source_color = vec3(0.03, 0.055, 0.12);
uniform vec3 rim_color : source_color = vec3(0.72, 0.86, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float flash = 0.0;

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}

void fragment() {
	float r = length((UV - 0.5) * 2.0);
	float aa = fwidth(r) * 1.2;
	float disc = 1.0 - smoothstep(0.80 - aa, 0.80 + aa, r);
	float rim = 1.0 - smoothstep(0.0, 0.05 + aa, abs(r - 0.80));
	float glow = exp(-pow(max(r - 0.80, 0.0) * 9.0, 2.0)) * (1.0 - disc);
	vec3 col = mix(fill_color + rim_color * flash * 0.5, rim_color, rim);
	ALBEDO = col;
	ALPHA = clamp(max(disc * 0.86, rim) + glow * 0.35, 0.0, 1.0) * fade;
}
