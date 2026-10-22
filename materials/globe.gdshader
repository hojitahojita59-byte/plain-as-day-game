shader_type spatial;
// Globo: costas (Natural Earth 110m) sobre reticula, con luz de dia suave. Mascara R = tierra, G = costa.

render_mode blend_mix, cull_back, unshaded, depth_draw_never, shadows_disabled;

uniform sampler2D map : filter_linear_mipmap, repeat_enable;

uniform vec3 line_color : source_color = vec3(0.52, 0.70, 0.96);
uniform vec3 fill_color : source_color = vec3(0.025, 0.05, 0.11);
uniform vec3 land_color : source_color = vec3(0.10, 0.19, 0.34);
uniform vec3 coast_color : source_color = vec3(0.80, 0.90, 1.0);
uniform float meridians = 24.0;
uniform float parallels = 12.0;
uniform float line_alpha : hint_range(0.0, 1.0) = 0.20;
uniform float fill_alpha : hint_range(0.0, 1.0) = 0.55;
uniform float land_alpha : hint_range(0.0, 1.0) = 0.30;
uniform float coast_alpha : hint_range(0.0, 1.0) = 0.90;
uniform vec3 rim_color : source_color = vec3(0.45, 0.68, 1.0);
uniform float rim_power : hint_range(1.0, 8.0) = 3.0;
// Luz fija en espacio de vista: arriba a la izquierda.
uniform vec3 light_dir = vec3(-0.55, 0.45, 0.70);

// Linea de reticula con antialias.
float grid_line(float v, float n, float w) {
	float f = fract(v * n);
	float d = min(f, 1.0 - f);
	return 1.0 - smoothstep(0.0, fwidth(v * n) * w, d);
}

void fragment() {
	// Mapa equirectangular: +0,5 con fract() para que la costura quede en el Pacifico.
	vec4 m = texture(map, vec2(fract(UV.x + 0.5), UV.y));
	float land = m.r;
	float coast = m.g;

	// Los meridianos se juntan en los polos: alli se apagan.
	float pole = smoothstep(0.02, 0.10, min(UV.y, 1.0 - UV.y));
	float g = max(grid_line(UV.x, meridians, 1.1) * pole, grid_line(UV.y, parallels, 1.1));
	float eq = 1.0 - smoothstep(0.0, fwidth(UV.y) * 2.0, abs(UV.y - 0.5));
	g = max(g * 0.75, eq * 0.9);

	float lit = clamp(dot(NORMAL, normalize(light_dir)), 0.0, 1.0);
	float shade = 0.42 + 0.78 * lit;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);

	vec3 base = mix(fill_color, land_color, land) * shade;
	vec3 col = base
		+ line_color * g * 0.42
		+ coast_color * coast * (0.55 + 0.55 * shade)
		+ rim_color * fres * 0.8;

	ALBEDO = col;
	ALPHA = clamp(
		fill_alpha
		+ land * land_alpha
		+ g * line_alpha
		+ coast * coast_alpha
		+ fres * 0.6, 0.0, 1.0);
}
