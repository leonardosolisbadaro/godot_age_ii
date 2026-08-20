## @file test_load_server_heightfield_use_case.gd
## @path res://tests/unit/use_cases/test_load_server_heightfield_use_case.gd
##
## @description
## Testes unitários AAA para LoadServerHeightfieldUseCase.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends GutTest

const LoadServerHeightfieldUseCaseClass = preload("res://src/use_cases/load_server_heightfield_use_case.gd")
const ChunkResourceAdapterClass = preload("res://src/adapters/chunk_resource_adapter.gd")


func test_load_server_heightfield_successfully() -> void:
	# Arrange
	var adapter = ChunkResourceAdapterClass.new("res://assets/maps")
	var use_case = LoadServerHeightfieldUseCaseClass.new()

	# Act
	var sampler = use_case.execute("16_24", adapter)

	# Assert
	assert_not_null(sampler, "Sampler deve ser instanciado com sucesso")
	assert_eq(sampler.grid_width, 256)
	assert_eq(sampler.grid_depth, 256)
	assert_eq(sampler.heights.size(), 65536)

	# Amostra a altura na origem mundial do chunk
	var h = sampler.get_height_at(sampler.world_origin.x, sampler.world_origin.z)
	assert_gt(h, -1000.0)
	assert_lt(h, 1000.0)
