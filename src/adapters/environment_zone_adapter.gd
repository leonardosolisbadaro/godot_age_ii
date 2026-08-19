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

	# Configura luz ambiente
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = env_data.ambient_light_color
	env.ambient_light_energy = env_data.ambient_light_energy

	# Configura névoa volumétrica/distância
	env.fog_enabled = env_data.fog_enabled
	env.fog_light_color = env_data.fog_color
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
