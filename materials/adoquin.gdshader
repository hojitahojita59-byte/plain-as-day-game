shader_type spatial;
render_mode cull_back, diffuse_burley;

// Adoquinado procedimental, en coordenadas de mundo.

uniform vec3 color_piedra : source_color = vec3(0.30, 0.28, 0.26);
uniform vec3 color_junta : source_color = vec3(0.17, 0.16, 0.15);
uniform float celdas = 2.5;
uniform float proporcion = 1.0;
uniform float junta : hint_range(0.01, 0.3) = 0.07;
uniform float variacion : hint_range(0.0, 0.6) = 0.16;
uniform float alabeo : hint_range(0.0, 1.0) = 0.5;
uniform float rugosidad : hint_range(0.0, 1.0) = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	// VERTEX viene en espacio de vista: pasar a mundo.
	vec3 mundo = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;

	vec2 uv = vec2(mundo.x, mundo.z / proporcion) * celdas;

	// Filas trabadas.
	float fila = floor(uv.y);
	uv.x += mod(fila, 2.0) * alabeo;

	vec2 celda = vec2(floor(uv.x), fila);
	vec2 f = vec2(fract(uv.x), fract(uv.y));

	// Distancia al borde -> junta.
	float d = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float mortero = smoothstep(0.0, junta, d);

	// Tono por losa.
	float r = hash21(celda);
	vec3 piedra = color_piedra * (1.0 + (r - 0.5) * 2.0 * variacion);

	ALBEDO = mix(color_junta, piedra, mortero);
	ROUGHNESS = rugosidad;
	SPECULAR = 0.15;
}
