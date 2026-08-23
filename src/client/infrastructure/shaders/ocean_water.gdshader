shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// --- Configurações de Água Clássica Lineage II (UE2) ---
uniform vec4 deep_color : source_color = vec4(0.04, 0.20, 0.35, 0.85);
uniform vec4 shallow_color : source_color = vec4(0.12, 0.42, 0.55, 0.65);

uniform float wave_speed : hint_range(0.0, 0.2) = 0.015;
uniform float wave_scale : hint_range(0.0001, 0.01) = 0.001;
uniform float metallic : hint_range(0.0, 1.0) = 0.05;
uniform float roughness : hint_range(0.0, 1.0) = 0.12;


void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// Ondulação suave de baixa frequência para reflexo solar agradável
	vec2 p = world_pos.xz * wave_scale;
	float w1 = sin(p.x * 6.28 + TIME * wave_speed * 10.0) * 0.05;
	float w2 = cos(p.y * 6.28 + TIME * wave_speed * 8.0) * 0.05;
	vec3 wave_n = normalize(vec3(w1, 1.0, w2));

	// Gradiente suave de Fresnel
	float fresnel = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 3.0);
	vec4 water_col = mix(shallow_color, deep_color, clamp(fresnel * 1.1, 0.0, 1.0));

	ALBEDO = water_col.rgb;
	ALPHA = water_col.a;
	NORMAL = (VIEW_MATRIX * vec4(wave_n, 0.0)).xyz;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = 0.5;
}
