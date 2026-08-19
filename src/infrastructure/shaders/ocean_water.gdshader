shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// --- Configurações Globais do Oceano UE2 (Lineage II) ---
uniform vec4 deep_color : source_color = vec4(0.02, 0.08, 0.20, 0.95);
uniform vec4 shallow_color : source_color = vec4(0.12, 0.45, 0.58, 0.65);
uniform vec4 foam_color : source_color = vec4(0.90, 0.95, 1.0, 0.85);

uniform float wave_speed : hint_range(0.0, 0.5) = 0.03;
uniform float wave_scale : hint_range(0.001, 1.0) = 0.03;
uniform float metallic : hint_range(0.0, 1.0) = 0.1;
uniform float roughness : hint_range(0.0, 1.0) = 0.15;


// Ondulação procedural de água clássica para reflexo solar da UE2
vec3 calculate_wave_normal(vec2 world_xz, float time) {
	vec2 p1 = world_xz * wave_scale + vec2(time * wave_speed, time * wave_speed * 0.7);
	vec2 p2 = world_xz * wave_scale * 1.5 - vec2(time * wave_speed * 0.8, time * wave_speed * 1.2);

	float d_x = sin(p1.x * 6.28) * 0.15 + cos(p2.x * 6.28) * 0.1;
	float d_z = cos(p1.y * 6.28) * 0.15 + sin(p2.y * 6.28) * 0.1;

	return normalize(vec3(d_x, 1.0, d_z));
}


void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wave_n = calculate_wave_normal(world_pos.xz, TIME);

	// Gradiente de cor de oceano clássico por Fresnel
	float fresnel = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 3.0);
	vec4 water_col = mix(shallow_color, deep_color, clamp(fresnel * 1.2, 0.0, 1.0));

	ALBEDO = water_col.rgb;
	ALPHA = water_col.a;
	NORMAL = (VIEW_MATRIX * vec4(wave_n, 0.0)).xyz;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = 0.6;
}
