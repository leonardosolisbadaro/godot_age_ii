## @file test_evaluate_chunk_water_presence_use_case.gd
## @path res://tests/unit/use_cases/test_evaluate_chunk_water_presence_use_case.gd
##
## @description
## Testes unitários AAA para EvaluateChunkWaterPresenceUseCase.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends GutTest

const EvaluateChunkWaterPresenceUseCaseClass = preload("res://src/use_cases/evaluate_chunk_water_presence_use_case.gd")
const EnvironmentZoneDataClass = preload("res://src/domain/environment_zone_data.gd")


func test_evaluate_water_presence() -> void:
	# Arrange
	var env_data = EnvironmentZoneDataClass.new("Talking Island Waters")
	env_data.water_volumes = [
		{ "name": "SeaLevel", "water_z_meters": 0.0, "is_water_zone": true }
	]
	var use_case = EvaluateChunkWaterPresenceUseCaseClass.new()

	# Act
	var res_submerged = use_case.execute(Vector3(10.0, -8.0, 20.0), env_data)
	var res_dry = use_case.execute(Vector3(10.0, 15.0, 20.0), env_data)

	# Assert
	assert_true(res_submerged["is_submerged"])
	assert_almost_eq(res_submerged["depth"], 8.0, 0.001)
	assert_almost_eq(res_submerged["water_level"], 0.0, 0.001)

	assert_false(res_dry["is_submerged"])
	assert_almost_eq(res_dry["depth"], 0.0, 0.001)
