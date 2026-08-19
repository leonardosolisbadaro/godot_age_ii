## @file test_stream_world_chunks_use_case.gd
## @path res://tests/unit/use_cases/test_stream_world_chunks_use_case.gd
##
## @description
## Testes unitários AAA para StreamWorldChunksUseCase.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends GutTest

const StreamWorldChunksUseCaseClass = preload("res://src/use_cases/stream_world_chunks_use_case.gd")
const TerrainChunkDataClass = preload("res://src/domain/terrain_chunk_data.gd")


func test_streaming_detection_load_and_unload() -> void:
	# Arrange: 3 Chunks em linha no eixo X (largura 100m cada)
	# C0 em X=0, C1 em X=200, C2 em X=600
	var c0 = TerrainChunkDataClass.new("chunk_0", 0, 0, Vector3(0.0, 0.0, 0.0), 100.0, 100.0)
	var c1 = TerrainChunkDataClass.new("chunk_1", 1, 0, Vector3(200.0, 0.0, 0.0), 100.0, 100.0)
	var c2 = TerrainChunkDataClass.new("chunk_2", 2, 0, Vector3(600.0, 0.0, 0.0), 100.0, 100.0)

	var known = { "chunk_0": c0, "chunk_1": c1, "chunk_2": c2 }
	var currently_loaded = ["chunk_0", "chunk_2"] # chunk_2 está carregado mas agora está longe

	var use_case = StreamWorldChunksUseCaseClass.new()

	# Act: Avatar está em (150, 0, 0) com raio de visão de 150 metros
	var res = use_case.execute(Vector3(150.0, 0.0, 0.0), 150.0, known, currently_loaded)

	# Assert
	# chunk_0 está a 150m (dentro do alcance com raio) -> Mantém
	# chunk_1 está a 50m -> Carrega (to_load)
	# chunk_2 está a 450m -> Descarrega (to_unload)
	assert_has(res["desired_active"], "chunk_0")
	assert_has(res["desired_active"], "chunk_1")
	assert_does_not_have(res["desired_active"], "chunk_2")

	assert_has(res["to_load"], "chunk_1")
	assert_does_not_have(res["to_load"], "chunk_0")

	assert_has(res["to_unload"], "chunk_2")
