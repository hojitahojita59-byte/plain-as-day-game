shader_type canvas_item;

// Textura de papel: fibra, grano y trasluz. Valores bajos a proposito.

uniform float fibra : hint_range(0.0, 0.2) = 0.035;
uniform float grano : hint_range(0.0, 0.2) = 0.028;
uniform float trasluz : hint_range(0.0, 0.3) = 0.07;

// Desgaste: a 0 por defecto (lo usa el dialogo); solo lo sube el expediente.
uniform float manchas : hint_range(0.0, 0.5) = 0.0;
uniform float bordes : hint_range(0.0, 0.6) = 0.0;
uniform float pliegues : hint_range(0.0, 0.3) = 0.0;


float hash(vec2 p) {
	p = fract(p * vec2(443.897, 441.423));
	p += dot(p, p + 19.19);
	return fract(p.x * p.y);
}

// Ruido suave. Va despues de hash: GLSL exige declarar antes de usar.
float suave(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Multiplicar sobre COLOR, no recalcular desde TEXTURE: ahi viaja el tinte (MODULATE).
void fragment() {
	// Hebras.
	float h = hash(vec2(floor(FRAGCOORD.x * 0.25), floor(FRAGCOORD.y * 2.0)));
	// Grano.
	float g = hash(FRAGCOORD.xy);

	float tono = 1.0 + (h - 0.5) * 2.0 * fibra + (g - 0.5) * 2.0 * grano;

	// Trasluz.
	vec2 d = UV - vec2(0.5);
	float centro = 1.0 - clamp(dot(d, d) * 2.4, 0.0, 1.0);
	tono += centro * trasluz;

	COLOR.rgb *= tono;

	if (manchas > 0.0) {
		float m = suave(UV * vec2(5.0, 3.5));
		m = smoothstep(0.62, 0.95, m);
		COLOR.rgb *= mix(vec3(1.0), vec3(0.82, 0.74, 0.60), m * manchas);
	}

	if (bordes > 0.0) {
		vec2 b = min(UV, vec2(1.0) - UV);
		float borde = 1.0 - smoothstep(0.0, 0.085, min(b.x, b.y));
		COLOR.rgb *= mix(vec3(1.0), vec3(0.72, 0.66, 0.55), borde * bordes);
	}

	if (pliegues > 0.0) {
		float v = 1.0 - smoothstep(0.0, 0.012, abs(UV.x - 0.5));
		float h = 1.0 - smoothstep(0.0, 0.010, abs(UV.y - 0.5));
		COLOR.rgb *= 1.0 - max(v, h) * pliegues;
	}
}
