## @file server_chunk_manager.gd
## @path res://src/server/infrastructure/server_chunk_manager.gd
##
## @description
## Gerenciador de relevo e dados espaciais do Servidor Headless (sem renderização visual).
## Carrega e mantém em memória RAM as matrizes binárias 'heightfield.bin' dos chunks ativos
## para validação autoritativa contínua de movimento e altitude.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
class_name ServerChunkManager
extends RefCounted

const ChunkResourceAdapterClass = preload("res://src/client/adapters/chunk_resource_adapter.gd")
const SampleTerrainAltitudeUseCaseClass = preload(
	"res://src/core/use_cases/sample_terrain_altitude_use_case.gd"
)
const ScaleConverterClass = preload("res://src/core/domain/scale_converter.gd")

# ==============================================================================
# ESTADO INTERNO
# ==============================================================================

var base_maps_path: String = "res://assets/maps"
var _cached_chunks: Dictionary = { } # { "17_25": TerrainChunkData }


func _init(p_base_path: String = "res://assets/maps") -> void:
	base_maps_path = p_base_path


## Retorna os dados espaciais completos de terreno do chunk (carrega sob demanda em RAM).
func get_terrain_chunk_data(chunk_name: String) -> RefCounted:
	if _cached_chunks.has(chunk_name):
		return _cached_chunks[chunk_name]

	var chunk_data = ChunkResourceAdapterClass.load_terrain_chunk_data(chunk_name, base_maps_path)
	if chunk_data != null:
		_cached_chunks[chunk_name] = chunk_data
		return chunk_data
	return null


## Amostra a cota real do solo (Y em metros) para qualquer coordenada de mundo contínua.
func sample_altitude(world_pos: Vector3) -> float:
	var coords = ScaleConverterClass.world_pos_to_chunk_coords(world_pos)
	var name_key = ScaleConverterClass.chunk_coords_to_name(coords)
	var chunk_data = get_terrain_chunk_data(name_key)
	if chunk_data != null:
		return SampleTerrainAltitudeUseCaseClass.execute(chunk_data, world_pos)
	return 0.0


## Retorna o total de chunks atualmente mantidos em memória RAM pelo servidor.
func get_cached_chunks_count() -> int:
	return _cached_chunks.size()


## Limpa a memória de chunks cacheados.
func clear_cache() -> void:
	_cached_chunks.clear()
