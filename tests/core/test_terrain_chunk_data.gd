## @file test_terrain_chunk_data.gd
## @path res://tests/core/test_terrain_chunk_data.gd
##
## @description
## Testes unitarios GUT AAA do TerrainChunkData.
## Valida instanciacao de metadados, construcao de AABB centrado e verificacao de contencao espacial.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
extends GutTest

const TerrainChunkDataClass = preload("res://src/core/domain/terrain_chunk_data.gd")


func test_chunk_data_initialization_and_bounds() -> void:
	# Arrange & Act
	var chunk = TerrainChunkDataClass.new(
		"16_24",
		Vector2i(16, 24),
		Vector3(-7864.32, 0.0, 18350.08),
		2621.44,
		256,
		-400.0,
		100.0,
	)

	# Assert
	assert_eq(chunk.chunk_name, "16_24", "Nome do chunk deve ser '16_24'.")
	assert_eq(chunk.coords, Vector2i(16, 24), "Coords devem ser (16, 24).")
	assert_eq(chunk.size_meters, 2621.44, "Tamanho deve ser 2621.44 metros.")
	assert_almost_eq(chunk.bounds_aabb.position.x, -7864.32 - 1310.72, 0.01, "AABB min X correto.")
	assert_almost_eq(chunk.bounds_aabb.position.z, 18350.08 - 1310.72, 0.01, "AABB min Z correto.")
	assert_eq(chunk.bounds_aabb.size, Vector3(2621.44, 500.0, 2621.44), "AABB size correto.")


func test_contains_world_point() -> void:
	# Arrange
	var origin = Vector3(0.0, 0.0, 0.0)
	var chunk = TerrainChunkDataClass.new(
		"20_18",
		Vector2i(20, 18),
		origin,
		2621.44,
		256,
		0.0,
		20.0,
	)

	# Act & Assert - Ponto interno
	assert_true(
		chunk.contains_world_point(Vector3(0.0, 10.0, 0.0)),
		"Ponto no centro deve estar contido.",
	)
	assert_true(
		chunk.contains_world_point(Vector3(1310.0, 0.0, 1310.0)),
		"Ponto perto da borda deve estar contido.",
	)

	# Act & Assert - Pontos externos
	assert_false(
		chunk.contains_world_point(Vector3(-1400.0, 0.0, 0.0)),
		"Ponto a oeste fora do chunk.",
	)
	assert_false(
		chunk.contains_world_point(Vector3(1400.0, 0.0, 0.0)),
		"Ponto a leste fora do chunk.",
	)
