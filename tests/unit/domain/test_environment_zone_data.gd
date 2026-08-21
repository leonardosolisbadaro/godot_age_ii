## @file test_environment_zone_data.gd
## @path res://tests/unit/domain/test_environment_zone_data.gd
##
## @description
## Testes unitários AAA para a entidade de domínio EnvironmentZoneData.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends GutTest

const EnvironmentZoneDataClass = preload("res://src/domain/environment_zone_data.gd")


func test_from_recipe_dictionary() -> void:
	# Arrange
	var data = EnvironmentZoneDataClass.new("Talking Island Zone")
	var recipe_dict = {
		"sun_light": {
			"direction": [0.0, -0.86604, 0.49997],
			"color_rgb": [1.0, 0.95, 0.85],
			"energy": 1.2
		},
		"ambient": {
			"color_rgb": [0.15, 0.18, 0.22],
			"energy": 0.8
		},
		"fog": {
			"enabled": true,
			"color_rgb": [0.65, 0.75, 0.85],
			"distance_range_meters": [80.0, 6400.0]
		},
		"water_volumes": {
			"WaterVolume0": {
				"water_z_meters": 0.0,
				"is_water_zone": true
			}
		}
	}

	# Act
	data.from_recipe_dictionary(recipe_dict)

	# Assert
	assert_eq(data.zone_name, "Talking Island Zone")
	assert_almost_eq(data.sun_direction, Vector3(0.0, -0.86604, 0.49997).normalized(), Vector3(0.001, 0.001, 0.001))
	assert_almost_eq(data.sun_energy, 1.2, 0.001)
	assert_almost_eq(data.fog_start_meters, 80.0, 0.001)
	assert_almost_eq(data.fog_end_meters, 6400.0, 0.001)
	assert_eq(data.water_volumes.size(), 1)
	assert_true(data.water_volumes.has("WaterVolume0"))


func test_water_submersion_and_depth() -> void:
	# Arrange
	var data = EnvironmentZoneDataClass.new("Ocean Zone")
	data.water_volumes = {
		"SeaLevel": {
			"water_z_meters": 0.0,
			"is_water_zone": true
		}
	}

	# Act & Assert
	# Posição acima do nível do mar (Y = 10.0m)
	assert_false(data.is_submerged_at(Vector3(0.0, 10.0, 0.0)), "Posição acima do nível do mar não deve estar submersa")
	assert_almost_eq(data.get_water_depth_at(Vector3(0.0, 10.0, 0.0)), 0.0, 0.001)

	# Posição exatamente no nível do mar (Y = 0.0m)
	assert_false(data.is_submerged_at(Vector3(0.0, 0.0, 0.0)))

	# Posição submersa 5 metros abaixo d'água (Y = -5.0m)
	assert_true(data.is_submerged_at(Vector3(0.0, -5.0, 0.0)), "Posição abaixo de 0m deve estar submersa")
	assert_almost_eq(data.get_water_depth_at(Vector3(0.0, -5.0, 0.0)), 5.0, 0.001, "Profundidade deve ser de 5 metros")
