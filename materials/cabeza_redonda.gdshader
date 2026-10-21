shader_type spatial;
render_mode diffuse_burley;

// Cabeza: piel, pelo y cara pintados sobre la esfera.

uniform vec4 piel : source_color = vec4(0.82, 0.62, 0.48, 1.0);
uniform vec4 pelo : source_color = vec4(0.2, 0.14, 0.1, 1.0);
uniform sampler2D rasgos : source_color, filter_linear_mipmap;
uniform sampler2D vello : source_color, filter_linear_mipmap;
// Cara: ancho en vuelta de U; frente y barbilla en V.
uniform float ancho = 0.27;
uniform float frente = 0.24;
uniform float barbilla = 0.86;
// Pelo: casquete arriba, nuca detras.
uniform float casquete = 0.2;
uniform float nuca = 0.62;

void fragment() {
	vec3 c = piel.rgb;
	// U centrada: 0 delante.
	float u = fract(UV.x + 0.5) - 0.5;
	float v = UV.y;

	bool detras = abs(u) > 0.25;
	if (v < casquete || (detras && v < nuca)) {
		c = pelo.rgb;
	}

	vec2 f = vec2(u / ancho + 0.5, (v - frente) / (barbilla - frente));
	if (f.x > 0.0 && f.x < 1.0 && f.y > 0.0 && f.y < 1.0) {
		vec4 r = texture(rasgos, f);
		c = mix(c, r.rgb, r.a);
		vec4 h = texture(vello, f);
		c = mix(c, pelo.rgb * h.rgb, h.a);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
