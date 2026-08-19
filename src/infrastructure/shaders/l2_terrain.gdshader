shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// --- Configuração Global de Tiling e Iluminação ---
uniform float base_tiling : hint_range(1.0, 128.0) = 32.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform float specular : hint_range(0.0, 1.0) = 0.15;

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

// --- Flags e Textura da Camada 9 (Splatmap 2: R) ---
uniform bool has_layer_9 = false;
uniform sampler2D tex_layer_9 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale_9 = vec2(1.0, 1.0);


void fragment() {
	vec2 uv = UV;

	// 1. Amostra os pesos dos Splatmaps
	vec4 s0 = texture(splatmap_0, uv);
	vec4 s1 = texture(splatmap_1, uv);
	vec4 s2 = texture(splatmap_2, uv);

	// 2. Cor Inicial: Textura Base com repetição global e multiplicador de camada
	vec2 uv_base = uv * base_tiling * uv_scale_base;
	vec4 final_color = texture(tex_base, uv_base);

	// 3. Mesclagem das Camadas 1 a 4 (Splatmap 0)
	if (has_layer_1 && s0.r > 0.001) {
		vec4 c1 = texture(tex_layer_1, uv * base_tiling * uv_scale_1);
		final_color = mix(final_color, c1, s0.r);
	}
	if (has_layer_2 && s0.g > 0.001) {
		vec4 c2 = texture(tex_layer_2, uv * base_tiling * uv_scale_2);
		final_color = mix(final_color, c2, s0.g);
	}
	if (has_layer_3 && s0.b > 0.001) {
		vec4 c3 = texture(tex_layer_3, uv * base_tiling * uv_scale_3);
		final_color = mix(final_color, c3, s0.b);
	}
	if (has_layer_4 && s0.a > 0.001) {
		vec4 c4 = texture(tex_layer_4, uv * base_tiling * uv_scale_4);
		final_color = mix(final_color, c4, s0.a);
	}

	// 4. Mesclagem das Camadas 5 a 8 (Splatmap 1)
	if (has_layer_5 && s1.r > 0.001) {
		vec4 c5 = texture(tex_layer_5, uv * base_tiling * uv_scale_5);
		final_color = mix(final_color, c5, s1.r);
	}
	if (has_layer_6 && s1.g > 0.001) {
		vec4 c6 = texture(tex_layer_6, uv * base_tiling * uv_scale_6);
		final_color = mix(final_color, c6, s1.g);
	}
	if (has_layer_7 && s1.b > 0.001) {
		vec4 c7 = texture(tex_layer_7, uv * base_tiling * uv_scale_7);
		final_color = mix(final_color, c7, s1.b);
	}
	if (has_layer_8 && s1.a > 0.001) {
		vec4 c8 = texture(tex_layer_8, uv * base_tiling * uv_scale_8);
		final_color = mix(final_color, c8, s1.a);
	}

	// 5. Mesclagem da Camada 9 (Splatmap 2)
	if (has_layer_9 && s2.r > 0.001) {
		vec4 c9 = texture(tex_layer_9, uv * base_tiling * uv_scale_9);
		final_color = mix(final_color, c9, s2.r);
	}

	ALBEDO = final_color.rgb;
	ROUGHNESS = roughness;
	SPECULAR = specular;
}
