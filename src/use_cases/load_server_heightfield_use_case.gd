## @file load_server_heightfield_use_case.gd
## @path res://src/use_cases/load_server_heightfield_use_case.gd
##
## @description
## Caso de uso para carregar o buffer binário de elevação de um chunk e instanciar
## o amostrador matemático HeightfieldSampler para simulação física no servidor.
##
## @created 2026-08-19
## @updated 2026-08-20
##
## @author Leonardo S. Badaró
extends RefCounted

const HeightfieldSamplerClass = preload("res://src/domain/heightfield_sampler.gd")
const TerrainChunkDataClass = preload("res://src/domain/terrain_chunk_data.gd")
const ChunkResourceAdapterClass = preload("res://src/adapters/chunk_resource_adapter.gd")


func execute(chunk_name: String, adapter: ChunkResourceAdapterClass) -> RefCounted:
	if not adapter:
		return null

	var meta_dict = adapter.load_chunk_meta_dict(chunk_name, true)
	if meta_dict.is_empty():
		return null

	var chunk_data = TerrainChunkDataClass.new()
	chunk_data.from_meta_dictionary(meta_dict)

	var raw_bytes = adapter.load_heightfield_bytes(chunk_name)
	if raw_bytes.is_empty():
		return null

	return HeightfieldSamplerClass.from_chunk_data_and_bytes(chunk_data, raw_bytes)
