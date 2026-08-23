## @file test_scale_converter.gd
## @path res://tests/core/test_scale_converter.gd
##
## @description
## Testes unitarios GUT AAA do ScaleConverter.
## Valida conversoes metricas UU <-> Metros (0.08m/UU), transformacao de coordenadas de chunk e origens globais.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
extends GutTest

const ScaleConverterClass = preload("res://src/core/domain/scale_converter.gd")


func test_scalar_conversions() -> void:
	# Arrange
	var uu_val: float = 100.0
	var meters_val: float = 8.0

	# Act
	var converted_meters = ScaleConverterClass.uu_to_meters(uu_val)
	var converted_uu = ScaleConverterClass.meters_to_uu(meters_val)

	# Assert
	assert_almost_eq(
		converted_meters,
		8.0,
		0.001,
		"100 UU devem equivaler a 8.0 metros (0.08m/UU).",
	)
	assert_almost_eq(converted_uu, 100.0, 0.001, "8.0 metros devem equivaler a 100 UU.")


func test_vector3_conversions() -> void:
	# Arrange
	var uu_vector = Vector3(100.0, 200.0, -300.0)

	# Act
	var meters_vector = ScaleConverterClass.vector3_uu_to_meters(uu_vector)
	var back_to_uu = ScaleConverterClass.vector3_meters_to_uu(meters_vector)

	# Assert
	assert_eq(meters_vector, Vector3(8.0, 16.0, -24.0), "Vetor deve ser multiplicado por 0.08.")
	assert_eq(back_to_uu, uu_vector, "Conversao inversa deve retornar o vetor original.")


func test_chunk_naming_conversions() -> void:
	# Arrange
	var coords = Vector2i(16, 24)
	var name_str = "16_24"

	# Act
	var result_name = ScaleConverterClass.chunk_coords_to_name(coords)
	var result_coords = ScaleConverterClass.chunk_name_to_coords(name_str)

	# Assert
	assert_eq(result_name, "16_24", "Coords (16, 24) devem gerar nome '16_24'.")
	assert_eq(result_coords, Vector2i(16, 24), "Nome '16_24' deve gerar coords (16, 24).")


func test_world_to_chunk_coords_mapping() -> void:
	# Arrange (Chunk 16_24 origin = [-7864.32, 0, 18350.08])
	var origin_16_24 = ScaleConverterClass.chunk_coords_to_world_origin_meters(Vector2i(16, 24))
	var sample_pos = origin_16_24 + Vector3(50.0, 0.0, 50.0)

	# Act
	var calculated_chunk = ScaleConverterClass.world_pos_to_chunk_coords(sample_pos)
	var local_pos = ScaleConverterClass.world_to_local_chunk_pos(sample_pos, calculated_chunk)

	# Assert
	assert_almost_eq(origin_16_24.x, -7864.32, 0.01, "Origin X de 16_24 deve ser -7864.32m.")
	assert_almost_eq(origin_16_24.z, 18350.08, 0.01, "Origin Z de 16_24 deve ser 18350.08m.")
	assert_eq(
		calculated_chunk,
		Vector2i(16, 24),
		"Posicao interna de 16_24 deve mapear para Vector2i(16, 24).",
	)
	assert_almost_eq(local_pos.x, 50.0, 0.001, "Posicao local X deve ser 50 metros.")
	assert_almost_eq(local_pos.z, 50.0, 0.001, "Posicao local Z deve ser 50 metros.")
