## @file load_chunk_metadata_use_case.gd
## @path res://src/use_cases/load_chunk_metadata_use_case.gd
##
## @description
## Caso de uso para carregar e validar metadados espaciais de um chunk do disco
## (servidor ou cliente) e instanciar a entidade TerrainChunkData correspondente.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends RefCounted

const TerrainChunkDataClass = preload("res://src/domain/terrain_chunk_data.gd")
const ChunkResourceAdapterClass = preload("res://src/adapters/chunk_resource_adapter.gd")


func execute(chunk_name: String, adapter: ChunkResourceAdapterClass, is_server: bool = true) -> RefCounted:
	if not adapter:
		return null

	var meta_dict = adapter.load_chunk_meta_dict(chunk_name, is_server)
	if meta_dict.is_empty():
		return null

	var chunk_data = TerrainChunkDataClass.new()
	chunk_data.from_meta_dictionary(meta_dict)
	return chunk_data
