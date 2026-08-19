## @file test_load_chunk_metadata_use_case.gd
## @path res://tests/unit/use_cases/test_load_chunk_metadata_use_case.gd
##
## @description
## Testes unitários AAA para LoadChunkMetadataUseCase.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends GutTest

const LoadChunkMetadataUseCaseClass = preload("res://src/use_cases/load_chunk_metadata_use_case.gd")
const ChunkResourceAdapterClass = preload("res://src/adapters/chunk_resource_adapter.gd")


func test_load_metadata_successfully() -> void:
	# Arrange
	var adapter = ChunkResourceAdapterClass.new("res://assets/maps")
	var use_case = LoadChunkMetadataUseCaseClass.new()

	# Act
	var chunk_data = use_case.execute("16_24", adapter, true)

	# Assert
	assert_not_null(chunk_data, "ChunkData deve ser instanciado com sucesso")
	assert_eq(chunk_data.chunk_name, "16_24")
	assert_eq(chunk_data.chunk_x, 16)
	assert_eq(chunk_data.chunk_y, 24)
	assert_gt(chunk_data.total_width_meters, 0.0)


func test_load_metadata_invalid_chunk_returns_null() -> void:
	# Arrange
	var adapter = ChunkResourceAdapterClass.new("res://assets/maps")
	var use_case = LoadChunkMetadataUseCaseClass.new()

	# Act
	var result = use_case.execute("invalid_chunk_name_999", adapter, true)

	# Assert
	assert_null(result, "Chunk inexistente deve retornar nulo")
