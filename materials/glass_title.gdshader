shader_type spatial;
// Hielo tallado del titulo: refracta lo de detras, escarcha, grietas, burbujas y destellos.

render_mode blend_mix, cull_back, depth_draw_always, unshaded, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

uniform vec3 deep_color : source_color = vec3(0.18, 0.42, 0.66);
uniform vec3 frost_color : source_color = vec3(0.78, 0.89, 1.0);
uniform vec3 rim_color : source_color = vec3(0.90, 0.97, 1.0);
// Desvio de la refraccion.
uniform float bend : hint_range(0.0, 0.2) = 0.045;
// 0 = hielo claro, 1 = todo escarcha.
uniform float frost : hint_range(0.0, 1.0) = 0.55;
uniform float crack_strength : hint_range(0.0, 3.0) = 1.1;
uniform float bubble_strength : hint_range(0.0, 2.0) = 0.7;
uniform float sparkle : hint_range(0.0, 4.0) = 1.6;
uniform float inner_glow : hint_range(0.0, 2.0) = 0.55;
// Bordes irregulares, en metros.
uniform float rough_edge : hint_range(0.0, 0.05) = 0.010;
uniform float opacity : hint_range(0.0, 1.0) = 0.94;

varying vec3 p_obj;
varying vec3 n_obj;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x),
			mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x),
			mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise3(p);
		p = p * 2.07 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return v;
}

// Distancia al borde entre celdas (F2 - F1): las grietas.
float crack_dist(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int z = -1; z <= 1; z++)
	for (int y = -1; y <= 1; y++)
	for (int x = -1; x <= 1; x++) {
		vec3 g = vec3(float(x), float(y), float(z));
		vec3 o = hash33(i + g);
		float d = length(g + o - f);
		if (d < d1) { d2 = d1; d1 = d; }
		else if (d < d2) { d2 = d; }
	}
	return d2 - d1;
}

// Relieve de la escarcha.
float relief(vec3 p) {
	return fbm(p * 7.0) * 0.7 + noise3(p * 23.0) * 0.3;
}

void vertex() {
	p_obj = VERTEX;
	n_obj = NORMAL;
	// Solo XY y por posicion XY: delante, detras y lados se mueven igual.
	vec2 j = vec2(noise3(vec3(VERTEX.xy * 7.0, 0.0)), noise3(vec3(VERTEX.xy * 7.0, 5.3))) - 0.5;
	VERTEX.xy += j * rough_edge * 2.0;
}

void fragment() {
	vec3 p = p_obj;
	float front = smoothstep(0.6, 0.9, abs(n_obj.z));

	// Normal con el relieve de la escarcha (gradiente en objeto, pasado a vista).
	float e = 0.012;
	float h0 = relief(p);
	vec3 grad = vec3(relief(p + vec3(e, 0.0, 0.0)) - h0,
		relief(p + vec3(0.0, e, 0.0)) - h0,
		relief(p + vec3(0.0, 0.0, e)) - h0) / e;
	vec3 gv = (VIEW_MATRIX * (MODEL_MATRIX * vec4(grad, 0.0))).xyz;
	gv = gv / max(length(MODEL_MATRIX[0].xyz), 0.0001);
	vec3 n = normalize(NORMAL - (gv - dot(gv, NORMAL) * NORMAL) * 0.09);

	// Zonas de escarcha y zonas claras.
	float cloud = fbm(p * 1.6 + vec3(3.0, 0.0, 0.0));
	float frosty = clamp(frost * 0.35 + smoothstep(0.36, 0.70, cloud) * 1.1 * frost, 0.0, 1.0);

	vec2 uv = SCREEN_UV + n.xy * bend;
	vec3 behind = textureLod(screen_tex, uv, mix(0.5, 4.0, frosty)).rgb;

	float fres = pow(1.0 - clamp(abs(dot(n, VIEW)), 0.0, 1.0), 2.5);

	// Cuerpo: azul hondo donde es claro, blanco frio donde hay escarcha.
	float top = smoothstep(-0.45, 0.5, p.y);
	vec3 body = mix(deep_color * 0.42, frost_color * 0.70, frosty);
	body *= 0.75 + 0.45 * top;
	body += deep_color * inner_glow * (0.35 + 0.65 * fbm(p * 3.1 + vec3(TIME * 0.05, 0.0, 0.0))) * (1.0 - frosty * 0.5);

	vec3 col = behind * mix(vec3(0.95, 1.0, 1.08), frost_color, 0.35) * (1.0 - frosty * 0.55) + body;

	// Grietas: planos que reflejan, lineas blancas finas y cortadas.
	float cd = crack_dist(p * vec3(3.2, 3.2, 1.6) + vec3(0.0, 0.0, 7.0));
	float cut = smoothstep(0.42, 0.62, fbm(p * 2.3 + vec3(11.0, 0.0, 0.0)));
	float crack = (1.0 - smoothstep(0.0, 0.035, cd)) * cut;
	float fine = (1.0 - smoothstep(0.0, 0.022, crack_dist(p * 8.5 + vec3(4.0, 2.0, 0.0))))
		* smoothstep(0.5, 0.7, fbm(p * 4.0 + vec3(0.0, 7.0, 0.0)));
	col += rim_color * (crack * 0.85 + fine * 0.3) * crack_strength * front;
	// Sombra a un lado de la grieta: le da hondura.
	col *= 1.0 - (1.0 - smoothstep(0.0, 0.09, cd)) * cut * 0.25 * front;

	// Burbujas: pocas, con borde claro y centro algo oscuro.
	vec3 bp = p * 13.0;
	vec3 bc = floor(bp);
	vec3 bo = hash33(bc + 17.0);
	float br = length(bp - bc - (0.3 + 0.4 * bo)) / (0.08 + 0.12 * bo.z);
	float has_bubble = step(0.82, hash13(bc + 3.0));
	float ring = smoothstep(0.75, 0.95, br) * (1.0 - smoothstep(0.95, 1.1, br));
	col += rim_color * ring * has_bubble * bubble_strength * front;
	col *= 1.0 - (1.0 - smoothstep(0.4, 0.9, br)) * has_bubble * 0.2 * front;

	// Brillo de la luz sobre el relieve.
	vec3 l = normalize(vec3(-0.35, 0.65, 0.68));
	float spec = pow(max(dot(reflect(-VIEW, n), l), 0.0), 48.0);
	col += rim_color * spec * 0.9;

	// Destellos sueltos que titilan.
	vec3 sp = floor(p * 38.0);
	float sh = hash13(sp + 41.0);
	float tw = pow(0.5 + 0.5 * sin(TIME * (1.2 + 2.0 * sh) + sh * 40.0), 12.0);
	vec3 sf = fract(p * 38.0) - 0.5;
	float star = smoothstep(0.22, 0.0, length(sf.xy)) * step(0.965, sh);
	col += vec3(1.0) * star * tw * sparkle * front;

	// Lados del bloque: hielo blanco y lechoso con vetas; borde muy claro.
	float veins = smoothstep(0.45, 0.9, fbm(vec3(p.x * 2.0, p.y * 9.0, p.z * 30.0)));
	vec3 side = mix(deep_color * 0.7 + frost_color * 0.35, rim_color * 1.25, clamp(veins * 0.45 + fres * 0.8, 0.0, 1.0));
	col = mix(side, col, front);

	// Contorno que brilla (bisel falso).
	col += rim_color * fres * 1.1;

	ALBEDO = col;
	ALPHA = opacity;
}
