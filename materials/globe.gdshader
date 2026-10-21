shader_type spatial;
// Globo: costas (Natural Earth 110m) sobre reticula. Mascara R = tierra, G = costa.

render_mode blend_mix, cull_back, unshaded;

uniform sampler2D map : filter_linear_mipmap, repeat_enable;

uniform vec3 line_color : source_color = vec3(0.62, 0.78, 0.95);
uniform vec3 fill_color : source_color = vec3(0.05, 0.09, 0.18);
uniform vec3 land_color : source_color = vec3(0.13, 0.22, 0.38);
uniform vec3 coast_color : source_color = vec3(0.82, 0.90, 1.0);
uniform float meridians = 24.0;
uniform float parallels = 12.0;
uniform float line_alpha : hint_range(0.0, 1.0) = 0.26;
uniform float fill_alpha : hint_range(0.0, 1.0) = 0.35;
uniform float land_alpha : hint_range(0.0, 1.0) = 0.34;
uniform float coast_alpha : hint_range(0.0, 1.0) = 0.95;
uniform vec3 rim_color : source_color = vec3(0.55, 0.72, 1.0);
uniform float rim_power : hint_range(1.0, 8.0) = 2.6;

// Linea de reticula con antialias.
float grid_line(float v, float n) {
	float f = fract(v * n);
	float d = min(f, 1.0 - f);
	return 1.0 - smoothstep(0.0, fwidth(v * n) * 1.6, d);
}

void fragment() {
	// Mapa equirectangular: +0,5 con fract() para que la costura quede en el Pacifico.
	vec4 m = texture(map, vec2(fract(UV.x + 0.5), UV.y));
	float land = m.r;
	float coast = m.g;

	float g = max(grid_line(UV.x, meridians), grid_line(UV.y, parallels));

	// Ecuador mas marcado.
	float eq = 1.0 - smoothstep(0.0, fwidth(UV.y) * 3.0, abs(UV.y - 0.5));
	g = max(g, eq * 0.9);

	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);

	vec3 base = mix(fill_color, land_color, land);
	base = mix(base, line_color, g * 0.55);
	ALBEDO = mix(base, coast_color, coast);

	EMISSION = line_color * g * 0.45
		+ coast_color * coast * 1.05
		+ rim_color * fres * 1.4;

	ALPHA = clamp(
		fill_alpha
		+ land * land_alpha
		+ g * line_alpha
		+ coast * coast_alpha
		+ fres * 0.5, 0.0, 1.0);
}
