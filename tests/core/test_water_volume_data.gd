## @file test_water_volume_data.gd
## @path res://tests/core/test_water_volume_data.gd
##
## @description
## Testes unitarios GUT AAA do WaterVolumeData.
## Valida contencao horizontal, cota de superficie e teste de submersao.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
extends GutTest

const WaterVolumeDataClass = preload("res://src/core/domain/water_volume_data.gd")


func test_water_volume_containment_and_submersion() -> void:
	# Arrange
	var aabb = AABB(Vector3(0.0, -50.0, 0.0), Vector3(100.0, 50.0, 100.0))
	var water = WaterVolumeDataClass.new("River_01", 0.0, aabb, "RIVER")

	# Act & Assert - Ponto fora
	assert_false(
		water.contains_horizontal_point(Vector3(150.0, 0.0, 50.0)),
		"Ponto X=150 fora dos limites.",
	)
	assert_false(water.is_submerged(Vector3(50.0, 5.0, 50.0)), "Ponto Y=5.0 acima da agua.")

	# Act & Assert - Ponto submerso
	assert_true(
		water.contains_horizontal_point(Vector3(50.0, -10.0, 50.0)),
		"Ponto dentro dos limites.",
	)
	assert_true(
		water.is_submerged(Vector3(50.0, -10.0, 50.0)),
		"Ponto Y=-10.0 deve estar submerso.",
	)
	assert_true(
		water.is_submerged(Vector3(50.0, 0.0, 50.0)),
		"Ponto exatamente na superficie deve estar submerso.",
	)
