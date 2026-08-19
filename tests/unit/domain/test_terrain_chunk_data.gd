## @file test_terrain_chunk_data.gd
## @path res://tests/unit/domain/test_terrain_chunk_data.gd
##
## @description
## Testes unitários AAA para a entidade de domínio TerrainChunkData.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends GutTest

const TerrainChunkDataClass = preload("res://src/domain/terrain_chunk_data.gd")


func test_initialization_with_default_values() -> void:
	# Arrange & Act
	var chunk = TerrainChunkDataClass.new("16_24", 16, 24, Vector3(100.0, -50.0, 200.0), 624.15, 624.15)

	# Assert
	assert_eq(chunk.chunk_name, "16_24")
	assert_eq(chunk.chunk_x, 16)
	assert_eq(chunk.chunk_y, 24)
	assert_eq(chunk.world_origin, Vector3(100.0, -50.0, 200.0))
	assert_almost_eq(chunk.total_width_meters, 624.15, 0.001)
	assert_almost_eq(chunk.total_depth_meters, 624.15, 0.001)


func test_from_meta_dictionary() -> void:
	# Arrange
	var chunk = TerrainChunkDataClass.new()
	var meta_dict = {
		"chunk_name": "17_25",
		"chunk_indices": [17, 25],
		"grid_resolution": [256, 256],
		"chunk_dimensions_meters": [624.15, 624.15],
		"world_origin_meters": [-6552.0, -150.0, 19659.0],
		"altitude_meters": {
			"min": -341.6,
			"max": -33.5
		}
	}

	# Act
	chunk.from_meta_dictionary(meta_dict)

	# Assert
	assert_eq(chunk.chunk_name, "17_25")
	assert_eq(chunk.chunk_x, 17)
	assert_eq(chunk.chunk_y, 25)
	assert_eq(chunk.world_origin, Vector3(-6552.0, -150.0, 19659.0))
	assert_almost_eq(chunk.min_altitude, -341.6, 0.001)
	assert_almost_eq(chunk.max_altitude, -33.5, 0.001)


func test_contains_world_point() -> void:
	# Arrange: Chunk centralizado em (0, 0, 0) com largura 100m e profundidade 100m [-50 .. +50]
	var chunk = TerrainChunkDataClass.new("center_chunk", 0, 0, Vector3.ZERO, 100.0, 100.0)

	# Act & Assert
	assert_true(chunk.contains_world_point(0.0, 0.0), "Origem central deve estar contida")
	assert_true(chunk.contains_world_point(49.9, -49.9), "Ponto interno perto da borda deve estar contido")
	assert_true(chunk.contains_world_point(-50.0, 50.0), "Ponto exato na borda deve estar contido")
	assert_false(chunk.contains_world_point(50.1, 0.0), "Ponto fora do limite X deve retornar falso")
	assert_false(chunk.contains_world_point(0.0, -50.1), "Ponto fora do limite Z deve retornar falso")


func test_get_local_coordinates() -> void:
	# Arrange: Chunk centralizado em (100, 0, 200) com tamanho 100x100 [X: 50..150, Z: 150..250]
	var chunk = TerrainChunkDataClass.new("offset_chunk", 1, 2, Vector3(100.0, 0.0, 200.0), 100.0, 100.0)

	# Act
	var local_min = chunk.get_local_coordinates(50.0, 150.0)
	var local_center = chunk.get_local_coordinates(100.0, 200.0)
	var local_max = chunk.get_local_coordinates(150.0, 250.0)

	# Assert
	assert_almost_eq(local_min.x, 0.0, 0.001)
	assert_almost_eq(local_min.y, 0.0, 0.001)
	assert_almost_eq(local_center.x, 50.0, 0.001)
	assert_almost_eq(local_center.y, 50.0, 0.001)
	assert_almost_eq(local_max.x, 100.0, 0.001)
	assert_almost_eq(local_max.y, 100.0, 0.001)
