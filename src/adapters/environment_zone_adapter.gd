## @file environment_zone_adapter.gd
## @path res://src/adapters/environment_zone_adapter.gd
##
## @description
## Adaptador de interface que traduz a entidade EnvironmentZoneData para as
## propriedades visuais de nós DirectionalLight3D e WorldEnvironment no Godot 4.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends RefCounted

const EnvironmentZoneDataClass = preload("res://src/domain/environment_zone_data.gd")


func apply_to_directional_light(env_data: EnvironmentZoneDataClass, light_node: DirectionalLight3D) -> void:
	if not env_data or not light_node:
		return

	light_node.light_color = env_data.sun_color
	light_node.light_energy = env_data.sun_energy

	# Orienta o nó de luz para apontar na direção do Sol
	if env_data.sun_direction.length_squared() > 0.001:
		light_node.basis = Basis.looking_at(env_data.sun_direction, Vector3.UP)


func apply_to_world_environment(env_data: EnvironmentZoneDataClass, world_env_node: WorldEnvironment) -> void:
	if not env_data or not world_env_node:
		return

	var env = world_env_node.environment
	if not env:
		env = Environment.new()
		world_env_node.environment = env

	# Configura céu e background
	var sky = Sky.new()
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.35, 0.55, 0.85)
	sky_mat.sky_horizon_color = Color(0.65, 0.75, 0.88)
	sky_mat.ground_bottom_color = Color(0.2, 0.2, 0.2)
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY

	# Configura luz ambiente
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = env_data.ambient_light_color
	env.ambient_light_energy = env_data.ambient_light_energy

	# Configura névoa volumétrica/distância calibrada
	env.fog_enabled = env_data.fog_enabled
	env.fog_light_color = env_data.fog_color
	env.fog_density = 0.00001
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
