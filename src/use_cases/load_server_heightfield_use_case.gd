## @file load_server_heightfield_use_case.gd
## @path res://src/use_cases/load_server_heightfield_use_case.gd
##
## @description
## Caso de uso para carregar os artefatos de física de servidor (heightfield.bin e chunk_meta.json)
## e instanciar a entidade de domínio HeightfieldSampler.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends RefCounted

const ChunkResourceAdapterClass = preload("res://src/adapters/chunk_resource_adapter.gd")
const HeightfieldSamplerClass = preload("res://src/domain/heightfield_sampler.gd")
const LoadChunkMetadataUseCaseClass = preload("res://src/use_cases/load_chunk_metadata_use_case.gd")


func execute(chunk_name: String, adapter: ChunkResourceAdapterClass) -> RefCounted:
	if not adapter:
		return null

	var meta_use_case = LoadChunkMetadataUseCaseClass.new()
	var chunk_data = meta_use_case.execute(chunk_name, adapter, true)
	if not chunk_data:
		return null

	var raw_bytes = adapter.load_heightfield_bytes(chunk_name)
	if raw_bytes.is_empty():
		return null

	return HeightfieldSamplerClass.from_chunk_data_and_bytes(chunk_data, raw_bytes)
