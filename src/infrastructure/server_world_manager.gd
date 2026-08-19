## @file server_world_manager.gd
## @path res://src/infrastructure/server_world_manager.gd
##
## @description
## Gerenciador de mundo autoritativo do servidor dedicado (Headless), mantendo
## matrizes de elevação e validando a física espacial de entidades sem GPU.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends RefCounted

const ChunkResourceAdapterClass = preload("res://src/adapters/chunk_resource_adapter.gd")
const LoadChunkMetadataUseCaseClass = preload("res://src/use_cases/load_chunk_metadata_use_case.gd")
const LoadServerHeightfieldUseCaseClass = preload("res://src/use_cases/load_server_heightfield_use_case.gd")
const SampleWorldAltitudeUseCaseClass = preload("res://src/use_cases/sample_world_altitude_use_case.gd")
const ValidatePlayerMovementUseCaseClass = preload("res://src/use_cases/validate_player_movement_use_case.gd")

var base_maps_path: String = "res://assets/maps"

var _chunks_data: Dictionary = {} # { "16_24": TerrainChunkData, ... }
var _samplers: Dictionary = {} # { "16_24": HeightfieldSampler, ... }

var _resource_adapter: RefCounted
var _meta_use_case: RefCounted
var _hf_use_case: RefCounted
var _altitude_use_case: RefCounted
var _movement_use_case: RefCounted


func _init(p_base_path: String = "res://assets/maps") -> void:
	base_maps_path = p_base_path
	_resource_adapter = ChunkResourceAdapterClass.new(base_maps_path)
	_meta_use_case = LoadChunkMetadataUseCaseClass.new()
	_hf_use_case = LoadServerHeightfieldUseCaseClass.new()
	_altitude_use_case = SampleWorldAltitudeUseCaseClass.new()
	_movement_use_case = ValidatePlayerMovementUseCaseClass.new()


func load_server_chunk(chunk_name: String) -> bool:
	var chunk_data = _meta_use_case.execute(chunk_name, _resource_adapter, true)
	if not chunk_data:
		return false

	var sampler = _hf_use_case.execute(chunk_name, _resource_adapter)
	if not sampler:
		return false

	_chunks_data[chunk_name] = chunk_data
	_samplers[chunk_name] = sampler
	return true


func get_altitude_at(world_x: float, world_z: float) -> Dictionary:
	return _altitude_use_case.execute(world_x, world_z, _chunks_data, _samplers)


func validate_movement(from_pos: Vector3, to_pos: Vector3, delta_time: float = 0.05, max_speed: float = 6.0) -> Dictionary:
	return _movement_use_case.execute(from_pos, to_pos, _chunks_data, _samplers, delta_time, max_speed)


func get_loaded_chunks() -> Array:
	return _chunks_data.keys()


func find_sampler_at(world_x: float, world_z: float) -> RefCounted:
	for c_name in _chunks_data.keys():
		var chunk = _chunks_data[c_name]
		if chunk and chunk.has_method("contains_world_point") and chunk.contains_world_point(world_x, world_z):
			return _samplers.get(c_name, null)
	return null


func get_chunk_name_at(world_x: float, world_z: float) -> String:
	for c_name in _chunks_data.keys():
		var chunk = _chunks_data[c_name]
		if chunk and chunk.has_method("contains_world_point") and chunk.contains_world_point(world_x, world_z):
			return c_name
	return ""
