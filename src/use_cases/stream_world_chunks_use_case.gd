## @file stream_world_chunks_use_case.gd
## @path res://src/use_cases/stream_world_chunks_use_case.gd
##
## @description
## Caso de uso para orquestração de streaming de chunks espaciais no mundo contínuo,
## calculando dinamicamente chunks a carregar e descarregar conforme a posição do avatar.
##
## @created 2026-08-19
## @updated 2026-08-20
##
## @author Leonardo S. Badaró
extends RefCounted

# ==============================================================================
# CONSTANTES SEMÂNTICAS DE STREAMING
# ==============================================================================

## @const DIAGONAL_RADIUS_FACTOR (float)
## O que: Fator de conversão de raio de meia-diagonal ($\frac{\sqrt{2}}{2} \approx 0.70710678$).
## Porque: Calcula a distância do centro do chunk até o seu vértice mais distante no plano horizontal.
const DIAGONAL_RADIUS_FACTOR: float = 0.70710678


func execute(
	avatar_pos: Vector3,
	view_radius_meters: float,
	known_chunks: Dictionary, # { "16_24": TerrainChunkData, ... }
	currently_loaded: Array, # ["16_24", ...]
) -> Dictionary:
	var desired_active: Array = []
	var to_load: Array = []
	var to_unload: Array = []

	var avatar_2d = Vector2(avatar_pos.x, avatar_pos.z)

	# 1. Identifica chunks que intersectam o raio de visão do avatar
	for c_name in known_chunks.keys():
		var chunk = known_chunks[c_name]
		if not chunk:
			continue

		var origin_2d = Vector2(chunk.world_origin.x, chunk.world_origin.z)
		var dist = avatar_2d.distance_to(origin_2d)
		var chunk_radius = maxf(chunk.total_width_meters, chunk.total_depth_meters) * DIAGONAL_RADIUS_FACTOR

		if dist <= (view_radius_meters + chunk_radius):
			desired_active.append(c_name)
			if not (c_name in currently_loaded):
				to_load.append(c_name)

	# 2. Identifica chunks carregados que saíram do raio de visão
	for c_name in currently_loaded:
		if not (c_name in desired_active):
			to_unload.append(c_name)

	return {
		"desired_active": desired_active,
		"to_load": to_load,
		"to_unload": to_unload,
	}
