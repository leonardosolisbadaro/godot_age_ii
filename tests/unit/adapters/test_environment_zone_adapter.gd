## @file test_environment_zone_adapter.gd
## @path res://tests/unit/adapters/test_environment_zone_adapter.gd
##
## @description
## Testes unitários AAA para EnvironmentZoneAdapter.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends GutTest

const EnvironmentZoneAdapterClass = preload("res://src/adapters/environment_zone_adapter.gd")
const EnvironmentZoneDataClass = preload("res://src/domain/environment_zone_data.gd")


func test_apply_to_directional_light() -> void:
	# Arrange
	var adapter = EnvironmentZoneAdapterClass.new()
	var env_data = EnvironmentZoneDataClass.new("TestZone")
	env_data.sun_color = Color(1.0, 0.9, 0.8)
	env_data.sun_energy = 1.4
	env_data.sun_direction = Vector3(0.0, -0.86604, 0.49997).normalized()

	var light = DirectionalLight3D.new()

	# Act
	adapter.apply_to_directional_light(env_data, light)

	# Assert
	assert_eq(light.light_color, Color(1.0, 0.9, 0.8))
	assert_almost_eq(light.light_energy, 1.4, 0.001)

	# Cleanup
	light.free()


func test_apply_to_world_environment() -> void:
	# Arrange
	var adapter = EnvironmentZoneAdapterClass.new()
	var env_data = EnvironmentZoneDataClass.new("TestZone")
	env_data.ambient_light_color = Color(0.1, 0.2, 0.3)
	env_data.ambient_light_energy = 0.75
	env_data.fog_enabled = true
	env_data.fog_color = Color(0.5, 0.6, 0.7)

	var world_env = WorldEnvironment.new()

	# Act
	adapter.apply_to_world_environment(env_data, world_env)

	# Assert
	assert_not_null(world_env.environment)
	assert_eq(world_env.environment.ambient_light_color, Color(0.1, 0.2, 0.3))
	assert_almost_eq(world_env.environment.ambient_light_energy, 0.75, 0.001)
	assert_true(world_env.environment.fog_enabled)
	assert_eq(world_env.environment.fog_light_color, Color(0.5, 0.6, 0.7))

	# Cleanup
	world_env.free()
