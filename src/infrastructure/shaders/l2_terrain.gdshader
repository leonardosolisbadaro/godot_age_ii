shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;

// --- Configuração Global de Tiling e Iluminação ---
// 256.0 repetições por chunk de 2621.44m = 10.24m por azulejo (1 quad exato da UE2)
uniform float base_tiling : hint_range(1.0, 512.0) = 256.0;
uniform float mipmap_bias : hint_range(-2.0, 2.0) = -0.75;
uniform float saturation_boost : hint_range(0.5, 2.0) = 1.15;
uniform vec3 color_tint : source_color = vec3(1.03, 1.05, 0.96);
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float specular : hint_range(0.0, 1.0) = 0.0;
uniform bool show_wireframe = false;

// --- Splatmaps RGBA ---
uniform sampler2D splatmap_0 : filter_linear_mipmap, repeat_disable;
uniform sampler2D splatmap_1 : filter_linear_mipmap, repeat_disable;
uniform sampler2D splatmap_2 : filter_linear_mipmap, repeat_disable;

// --- Textura Base (Camada 0) ---
uniform sampler2D tex_base : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale_base = vec2(1.0, 1.0);

// --- Flags e Texturas das Camadas 1 a 4 (Splatmap 0: R, G, B, A) ---
uniform bool has_layer_1 = false;
uniform sampler2D tex_layer_1 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale_1 = vec2(1.0, 1.0);

uniform bool has_layer_2 = false;
uniform sampler2D tex_layer_2 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale_2 = vec2(1.0, 1.0);

uniform bool has_layer_3 = false;
uniform sampler2D tex_layer_3 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale_3 = vec2(1.0, 1.0);

uniform bool has_layer_4 = false;
uniform sampler2D tex_layer_4 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale_4 = vec2(1.0, 1.0);

// --- Flags e Texturas das Camadas 5 a 8 (Splatmap 1: R, G, B, A) ---
uniform bool has_layer_5 = false;
uniform sampler2D tex_layer_5 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale_5 = vec2(1.0, 1.0);

uniform bool has_layer_6 = false;
uniform sampler2D tex_layer_6 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale_6 = vec2(1.0, 1.0);

uniform bool has_layer_7 = false;
uniform sampler2D tex_layer_7 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale_7 = vec2(1.0, 1.0);

uniform bool has_layer_8 = false;
uniform sampler2D tex_layer_8 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale_8 = vec2(1.0, 1.0);

// --- Flags e Texturas das Camadas 9 a 12 (Splatmap 2: R, G, B, A) ---
uniform bool has_layer_9 = false;
uniform sampler2D tex_layer_9 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale_9 = vec2(1.0, 1.0);

uniform bool has_layer_10 = false;
uniform sampler2D tex_layer_10 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale_10 = vec2(1.0, 1.0);

uniform bool has_layer_11 = false;
uniform sampler2D tex_layer_11 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale_11 = vec2(1.0, 1.0);

uniform bool has_layer_12 = false;
uniform sampler2D tex_layer_12 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale_12 = vec2(1.0, 1.0);


void fragment() {
	vec2 uv = UV;

	// 1. Amostra os pesos dos Splatmaps
	vec4 s0 = texture(splatmap_0, uv);
	vec4 s1 = texture(splatmap_1, uv);
	vec4 s2 = texture(splatmap_2, uv);

	// 2. Base de solo (Camada 0)
	vec2 uv_base = uv * base_tiling * uv_scale_base;
	vec4 final_color = texture(tex_base, uv_base, mipmap_bias);

	// 3. Composição Multi-Pass em ordem estrita de camadas da UE2
	// Camadas 1 a 4 (Rochas, Pedras e Grama Base)
	if (has_layer_1 && s0.r > 0.001) {
		vec4 c1 = texture(tex_layer_1, uv * base_tiling * uv_scale_1, mipmap_bias);
		final_color = mix(final_color, c1, s0.r);
	}
	if (has_layer_2 && s0.g > 0.001) {
		vec4 c2 = texture(tex_layer_2, uv * base_tiling * uv_scale_2, mipmap_bias);
		final_color = mix(final_color, c2, s0.g);
	}
	if (has_layer_3 && s0.b > 0.001) {
		vec4 c3 = texture(tex_layer_3, uv * base_tiling * uv_scale_3, mipmap_bias);
		final_color = mix(final_color, c3, s0.b);
	}
	if (has_layer_4 && s0.a > 0.001) {
		vec4 c4 = texture(tex_layer_4, uv * base_tiling * uv_scale_4, mipmap_bias);
		final_color = mix(final_color, c4, s0.a);
	}

	// Camadas 5 a 8 (Penhascos, Estradas de Terra e Caminhos)
	if (has_layer_5 && s1.r > 0.001) {
		vec4 c5 = texture(tex_layer_5, uv * base_tiling * uv_scale_5, mipmap_bias);
		final_color = mix(final_color, c5, s1.r);
	}
	if (has_layer_6 && s1.g > 0.001) {
		vec4 c6 = texture(tex_layer_6, uv * base_tiling * uv_scale_6, mipmap_bias);
		final_color = mix(final_color, c6, s1.g);
	}
	if (has_layer_7 && s1.b > 0.001) {
		vec4 c7 = texture(tex_layer_7, uv * base_tiling * uv_scale_7, mipmap_bias);
		final_color = mix(final_color, c7, s1.b);
	}
	if (has_layer_8 && s1.a > 0.001) {
		vec4 c8 = texture(tex_layer_8, uv * base_tiling * uv_scale_8, mipmap_bias);
		final_color = mix(final_color, c8, s1.a);
	}

	// Camadas 9 a 12 (Solo de grama curta e detalhes adicionais)
	if (has_layer_9 && s2.r > 0.001) {
		vec4 c9 = texture(tex_layer_9, uv * base_tiling * uv_scale_9, mipmap_bias);
		final_color = mix(final_color, c9, s2.r);
	}
	if (has_layer_10 && s2.g > 0.001) {
		vec4 c10 = texture(tex_layer_10, uv * base_tiling * uv_scale_10, mipmap_bias);
		final_color = mix(final_color, c10, s2.g);
	}
	if (has_layer_11 && s2.b > 0.001) {
		vec4 c11 = texture(tex_layer_11, uv * base_tiling * uv_scale_11, mipmap_bias);
		final_color = mix(final_color, c11, s2.b);
	}
	if (has_layer_12 && s2.a > 0.001) {
		vec4 c12 = texture(tex_layer_12, uv * base_tiling * uv_scale_12, mipmap_bias);
		final_color = mix(final_color, c12, s2.a);
	}

	// Ajuste de saturação e calor cromático para fidelidade 1:1 com a paleta original da UE2
	float luma = dot(final_color.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 saturated = mix(vec3(luma), final_color.rgb, saturation_boost);
	vec3 out_color = saturated * color_tint;

	// Wireframe ultraleve direto no shader (zero impacto em FPS)
	if (show_wireframe) {
		vec2 grid = abs(fract(uv * 256.0 - 0.5) - 0.5) / (fwidth(uv * 256.0) + vec2(0.0001));
		float line = min(grid.x, grid.y);
		float wire = 1.0 - clamp(line, 0.0, 1.0);
		out_color = mix(out_color, vec3(0.1, 0.95, 0.3), wire * 0.75);
	}

	ALBEDO = out_color;
	ROUGHNESS = roughness;
	SPECULAR = specular;
}
