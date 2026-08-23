## @file test_environment_zone_data.gd
## @path res://tests/core/test_environment_zone_data.gd
##
## @description
## Testes unitarios GUT AAA do EnvironmentZoneData.
## Valida valores padrao e normalizacao da direcao solar.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
extends GutTest

const EnvironmentZoneDataClass = preload("res://src/core/domain/environment_zone_data.gd")


func test_environment_zone_defaults_and_normalization() -> void:
	# Arrange & Act
	var env = EnvironmentZoneDataClass.new(
		Color(1.0, 1.0, 1.0),
		Color(0.2, 0.2, 0.2),
		Color(0.5, 0.5, 0.5),
		0.005,
		Vector3(0.0, -10.0, 0.0),
	)

	# Assert
	assert_eq(env.sun_color, Color(1.0, 1.0, 1.0), "Cor do sol correta.")
	assert_almost_eq(env.sun_direction.length(), 1.0, 0.001, "Direcao solar deve ser normalizada.")
	assert_eq(env.sun_direction, Vector3(0.0, -1.0, 0.0), "Vetor normalizado para baixo.")
