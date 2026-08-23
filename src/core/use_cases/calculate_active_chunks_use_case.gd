## @file calculate_active_chunks_use_case.gd
## @path res://src/core/use_cases/calculate_active_chunks_use_case.gd
##
## @description
## Caso de uso puro para calcular a grade de chunks que devem ser mantidos ativos,
## carregados ou descarregados em memoria com base na posicao de um ponto focal.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
class_name CalculateActiveChunksUseCase
extends RefCounted

const ScaleConverterClass = preload("res://src/core/domain/scale_converter.gd")

# ==============================================================================
# CÁLCULO DE CHUNKS ATIVOS
# ==============================================================================


## Executa o cálculo de chunks ativos em uma grade (2 * radius + 1)^2 ao redor da posicao.
static func execute(
	focal_world_pos: Vector3,
	radius_chunks: int,
	currently_loaded_coords: Array[Vector2i],
) -> Dictionary:
	var center_chunk = ScaleConverterClass.world_pos_to_chunk_coords(focal_world_pos)
	var active_set: Dictionary = { }
	var active_list: Array[Vector2i] = []

	for dy in range(-radius_chunks, radius_chunks + 1):
		for dx in range(-radius_chunks, radius_chunks + 1):
			var target_coord = center_chunk + Vector2i(dx, dy)
			active_set[target_coord] = true
			active_list.append(target_coord)

	var to_load: Array[Vector2i] = []
	for coord in active_list:
		if not currently_loaded_coords.has(coord):
			to_load.append(coord)

	var to_unload: Array[Vector2i] = []
	for loaded_coord in currently_loaded_coords:
		if not active_set.has(loaded_coord):
			to_unload.append(loaded_coord)

	return {
		"center": center_chunk,
		"active": active_list,
		"to_load": to_load,
		"to_unload": to_unload,
	}
