## @file scale_converter.gd
## @path res://src/core/domain/scale_converter.gd
##
## @description
## Conversor deterministico de escala e coordenadas espaciais entre Unreal Units (UU)
## de Lineage II e o sistema metrico padrão da Godot Engine (metros).
## Centraliza calculos de limites de chunks (2621.44m por chunk), origens globais e transformacoes espaciais.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
class_name ScaleConverter
extends RefCounted

# ==============================================================================
# CONSTANTES DE ESCALA E DIMENSÕES DE MUNDO (LINEAGE II)
# ==============================================================================

## Quantidade de Unreal Units equivalentes a 1 metro na conversao padrão de L2 (unit_scale = 0.08 / 12.5 UU/m).
const UU_PER_METER: float = 12.5

## Fator de conversão inverso de Unreal Units para metros (0.08m por UU).
const METERS_PER_UU: float = 0.08

## Tamanho exato de 1 chunk de terreno de Lineage II em metros (256 celulas * 128 UU * 0.08m = 2621.44 metros).
const CHUNK_SIZE_METERS: float = 2621.44

## Metade da dimensão do chunk em metros (1310.72m do centro ate a borda).
const CHUNK_HALF_SIZE_METERS: float = CHUNK_SIZE_METERS * 0.5

## Offset de índice de chunk padrão de Lineage II no eixo X (colunas).
## Ex: Chunk 16 -> (16 - 19) * 2621.44 = -7864.32m
const CHUNK_OFFSET_X: int = 19

## Offset de índice de chunk padrão de Lineage II no eixo Y (linhas).
## Ex: Chunk 24 -> (24 - 17) * 2621.44 = +18350.08m
const CHUNK_OFFSET_Y: int = 17

# ==============================================================================
# CONVERSÕES DE ESCALA MÉTRICA
# ==============================================================================


## Converte valor escalar de Unreal Units para metros.
static func uu_to_meters(uu_value: float) -> float:
	return uu_value * METERS_PER_UU


## Converte valor escalar de metros para Unreal Units.
static func meters_to_uu(meters_value: float) -> float:
	return meters_value * UU_PER_METER


## Converte um vetor Vector3 de coordenadas Unreal Units para metros na Godot.
static func vector3_uu_to_meters(uu_vector: Vector3) -> Vector3:
	return uu_vector * METERS_PER_UU


## Converte um vetor Vector3 de metros na Godot para Unreal Units.
static func vector3_meters_to_uu(meters_vector: Vector3) -> Vector3:
	return meters_vector * UU_PER_METER

# ==============================================================================
# CONVERSÕES DE CHUNKS E COORDENADAS ESPACIAIS
# ==============================================================================


## Converte coordenadas de índice de chunk (ex: Vector2i(16, 24)) para string formatada ("16_24").
static func chunk_coords_to_name(coords: Vector2i) -> String:
	return "%d_%d" % [coords.x, coords.y]


## Converte o nome de um chunk (ex: "16_24") para Vector2i(16, 24).
static func chunk_name_to_coords(chunk_name: String) -> Vector2i:
	var parts = chunk_name.split("_")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(parts[0].to_int(), parts[1].to_int())


## Calcula o centro exato no espaço de mundo (em metros) de um chunk.
static func chunk_coords_to_world_origin_meters(coords: Vector2i) -> Vector3:
	var world_x = float(coords.x - CHUNK_OFFSET_X) * CHUNK_SIZE_METERS
	var world_z = float(coords.y - CHUNK_OFFSET_Y) * CHUNK_SIZE_METERS
	return Vector3(world_x, 0.0, world_z)


## Determina a coordenada de chunk (Vector2i) correspondente a uma posição de mundo em metros.
static func world_pos_to_chunk_coords(world_pos: Vector3) -> Vector2i:
	var chunk_x = int(floor((world_pos.x + CHUNK_HALF_SIZE_METERS) / CHUNK_SIZE_METERS)) + CHUNK_OFFSET_X
	var chunk_y = int(floor((world_pos.z + CHUNK_HALF_SIZE_METERS) / CHUNK_SIZE_METERS)) + CHUNK_OFFSET_Y
	return Vector2i(chunk_x, chunk_y)


## Converte uma posição de mundo absoluta em metros para a coordenada local interna do chunk (-1310.72 a +1310.72).
static func world_to_local_chunk_pos(world_pos: Vector3, coords: Vector2i) -> Vector3:
	var origin = chunk_coords_to_world_origin_meters(coords)
	return world_pos - origin
