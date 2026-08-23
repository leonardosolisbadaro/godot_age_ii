## @file terrain_chunk_data.gd
## @path res://src/core/domain/terrain_chunk_data.gd
##
## @description
## Entidade imutavel do Core Domain representando metadados e limites espaciais
## de um chunk de terreno de Lineage II (2621.44m x 2621.44m).
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
class_name TerrainChunkData
extends RefCounted

# ==============================================================================
# PROPRIEDADES DE DOMÍNIO IMUTÁVEIS
# ==============================================================================

var chunk_name: String
var coords: Vector2i
var world_origin: Vector3
var size_meters: float
var quads_per_side: int
var min_height: float
var max_height: float
var bounds_aabb: AABB


func _init(
	p_name: String,
	p_coords: Vector2i,
	p_world_origin: Vector3,
	p_size_meters: float = 2621.44,
	p_quads_per_side: int = 256,
	p_min_height: float = -500.0,
	p_max_height: float = 500.0,
) -> void:
	chunk_name = p_name
	coords = p_coords
	world_origin = p_world_origin
	size_meters = p_size_meters
	quads_per_side = p_quads_per_side
	min_height = p_min_height
	max_height = p_max_height

	var half_size = size_meters * 0.5
	var height_range = maxf(max_height - min_height, 1.0)
	bounds_aabb = AABB(
		Vector3(world_origin.x - half_size, min_height, world_origin.z - half_size),
		Vector3(size_meters, height_range, size_meters),
	)


## Verifica se uma posição de mundo tridimensional (em metros) está contida nos limites AABB deste chunk.
func contains_world_point(world_pos: Vector3) -> bool:
	var half_size = size_meters * 0.5
	return (
		world_pos.x >= (world_origin.x - half_size)
		and world_pos.x <= (world_origin.x + half_size)
		and world_pos.z >= (world_origin.z - half_size) and world_pos.z
		<= (world_origin.z + half_size)
	)
