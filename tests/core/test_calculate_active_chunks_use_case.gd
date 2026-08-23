## @file test_calculate_active_chunks_use_case.gd
## @path res://tests/core/test_calculate_active_chunks_use_case.gd
##
## @description
## Testes unitarios GUT AAA do CalculateActiveChunksUseCase.
## Valida grade de streaming 3x3 (raio 1) e identificacao correta de chunks a carregar e descarregar.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
extends GutTest

const CalculateActiveChunksUseCaseClass = preload(
	"res://src/core/use_cases/calculate_active_chunks_use_case.gd"
)
const ScaleConverterClass = preload("res://src/core/domain/scale_converter.gd")


func test_active_chunks_calculation_3x3() -> void:
	# Arrange
	var origin_16_24 = ScaleConverterClass.chunk_coords_to_world_origin_meters(Vector2i(16, 24))
	var focal_pos = origin_16_24 + Vector3(50.0, 0.0, 50.0) # Dentro de 16_24
	var currently_loaded: Array[Vector2i] = [
		Vector2i(16, 24),
		Vector2i(10, 10), # Fora da grade, deve ser descarregado
	]

	# Act
	var result = CalculateActiveChunksUseCaseClass.execute(focal_pos, 1, currently_loaded)

	# Assert
	assert_eq(result.center, Vector2i(16, 24), "Centro deve ser (16, 24).")
	assert_eq(result.active.size(), 9, "Raio 1 deve gerar grade 3x3 de 9 chunks.")
	assert_true(result.active.has(Vector2i(15, 23)), "Chunk vizinho NW deve estar ativo.")
	assert_true(result.active.has(Vector2i(17, 25)), "Chunk vizinho SE deve estar ativo.")

	# to_load: 8 novos chunks (dos 9 ativos, 16_24 ja estava carregado)
	assert_eq(result.to_load.size(), 8, "Devem haver 8 chunks para carregar.")
	assert_false(result.to_load.has(Vector2i(16, 24)), "16_24 ja carregado nao deve estar em to_load.")

	# to_unload: 10_10 estava carregado mas nao esta nos 9 ativos
	assert_eq(result.to_unload.size(), 1, "Deve haver 1 chunk para descarregar.")
	assert_true(result.to_unload.has(Vector2i(10, 10)), "10_10 deve estar em to_unload.")
