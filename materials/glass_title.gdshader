shader_type spatial;
// Vidrio esmerilado del titulo. ALPHA = 1 pero va en cola transparente para leer la pantalla.

render_mode blend_mix, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

// 0 = cristal claro, 1 = opaco.
uniform float frost : hint_range(0.0, 1.0) = 0.45;
uniform float bend : hint_range(0.0, 0.25) = 0.055;
uniform vec3 tint : source_color = vec3(0.80, 0.86, 1.0);
// Brillo de borde (TextMesh no tiene bisel).
uniform vec3 edge_color : source_color = vec3(0.90, 0.94, 1.0);
uniform float edge_power : hint_range(1.0, 8.0) = 3.2;
uniform float edge_strength : hint_range(0.0, 4.0) = 1.6;
uniform float glass_roughness : hint_range(0.0, 1.0) = 0.12;

void fragment() {
	// NORMAL en espacio de vista: su xy sirve de desvio.
	vec2 uv = SCREEN_UV + NORMAL.xy * bend;

	// Desenfoque por mipmaps.
	vec3 behind = textureLod(screen_tex, uv, frost * 5.0).rgb;

	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), edge_power);

	ALBEDO = behind * tint;
	EMISSION = edge_color * fres * edge_strength;
	ROUGHNESS = glass_roughness;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	ALPHA = 1.0;
}
