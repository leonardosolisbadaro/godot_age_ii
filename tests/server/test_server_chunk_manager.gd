## @file test_server_chunk_manager.gd
## @path res://tests/server/test_server_chunk_manager.gd
##
## @description
## Testes unitarios GUT AAA do ServerChunkManager (Headless).
## Valida carregamento em memoria RAM de matrizes binarias de relevo sem nos visuais.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
extends GutTest

const ServerChunkManagerClass = preload("res://src/server/infrastructure/server_chunk_manager.gd")


func test_server_chunk_manager_initialization() -> void:
	# Arrange & Act
	var mgr = ServerChunkManagerClass.new()

	# Assert
	assert_not_null(mgr, "ServerChunkManager deve ser instanciado.")
	assert_eq(mgr.get_cached_chunks_count(), 0, "Cache inicial deve estar vazio.")


func test_server_chunk_manager_loads_and_samples_altitude() -> void:
	# Arrange
	var mgr = ServerChunkManagerClass.new()
	# Coordenadas mundiais de Talking Island Village (Chunk 17_25)
	var village_pos = Vector3(-5420.0, 0.0, 20725.0)

	# Act
	var chunk_data = mgr.get_terrain_chunk_data("17_25")
	var altitude = mgr.sample_altitude(village_pos)

	# Assert
	assert_not_null(chunk_data, "ChunkData de 17_25 deve ser carregado em memoria.")
	assert_eq(mgr.get_cached_chunks_count(), 1, "Cache deve conter 1 chunk indexado.")
	assert_gt(altitude, -500.0, "Altitude amostrada deve ser valida (>-500m).")
	assert_lt(altitude, 500.0, "Altitude amostrada deve ser valida (<500m).")
