shader_type canvas_item;

// Tramado Bayer 4x4 en coordenadas de pantalla. niveles alto = sutil.

uniform sampler2D pantalla : hint_screen_texture, filter_nearest;

uniform float niveles : hint_range(6.0, 64.0) = 40.0;
// 1 = tramado puro.
uniform float fuerza : hint_range(0.0, 1.0) = 0.55;

const float BAYER[16] = float[](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0
);

void fragment() {
	vec3 color = texture(pantalla, SCREEN_UV).rgb;

	int x = int(mod(FRAGCOORD.x, 4.0));
	int y = int(mod(FRAGCOORD.y, 4.0));
	// Umbral centrado en 0 para no cambiar el brillo medio.
	float umbral = (BAYER[y * 4 + x] / 16.0) - 0.5;

	vec3 tramado = floor(color * niveles + umbral) / niveles;
	COLOR = vec4(mix(color, tramado, fuerza), 1.0);
}
