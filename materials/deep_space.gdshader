shader_type sky;
// Fondo lejano: nebulosas y estrellas sin paralaje.

uniform vec3 base_color : source_color = vec3(0.007, 0.008, 0.020);
uniform vec3 nebula_a : source_color = vec3(0.34, 0.16, 0.52);
uniform vec3 nebula_b : source_color = vec3(0.10, 0.20, 0.55);
uniform float nebula_strength : hint_range(0.0, 2.0) = 0.42;
uniform float far_stars : hint_range(0.0, 2.0) = 0.55;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i);
	float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(
		mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y),
		f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise3(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);

	float n1 = fbm(d * 2.6);
	float n2 = fbm(d * 5.1 + vec3(19.7, 4.3, 11.1));

	vec3 col = base_color;
	col = mix(col, nebula_a, smoothstep(0.56, 1.0, n1) * 0.9 * nebula_strength);
	col = mix(col, nebula_b, smoothstep(0.62, 1.0, n2) * 0.55 * nebula_strength);

	// Una estrella redonda por celda, en pocas celdas.
	vec3 cell = floor(d * 260.0);
	float r = hash13(cell);
	if (r > 0.9980) {
		vec3 centre = (cell + 0.5) / 260.0;
		float dist = length(d - normalize(centre));
		float dot_ = smoothstep(0.0035, 0.0, dist);
		float bright = (0.35 + 0.65 * hash13(cell + 7.0)) * far_stars;
		col += vec3(dot_ * bright);
	}

	COLOR = col;
}
