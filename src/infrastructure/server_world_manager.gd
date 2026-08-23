## @file server_world_manager.gd
## @path res://src/infrastructure/server_world_manager.gd
##
## @description
## Gerenciador de mundo autoritativo do servidor dedicado (Headless), mantendo
## matrizes de elevação e validando a física espacial de entidades sem GPU.
##
## @created 2026-08-19
## @updated 2026-08-20
##
## @author Leonardo S. Badaró
extends RefCounted

const ChunkResourceAdapterClass = preload("res://src/adapters/chunk_resource_adapter.gd")
const LoadChunkMetadataUseCaseClass = preload("res://src/use_cases/load_chunk_metadata_use_case.gd")
const LoadServerHeightfieldUseCaseClass = preload(
	"res://src/use_cases/load_server_heightfield_use_case.gd"
)
const SampleWorldAltitudeUseCaseClass = preload(
	"res://src/use_cases/sample_world_altitude_use_case.gd"
)
const ValidatePlayerMovementUseCaseClass = preload(
	"res://src/use_cases/validate_player_movement_use_case.gd"
)
const LoadServerStaticObstaclesUseCaseClass = preload(
	"res://src/use_cases/load_server_static_obstacles_use_case.gd"
)
const ServerMovementValidatorClass = preload("res://src/domain/server_movement_validator.gd")

var base_maps_path: String = "res://assets/maps"

var _chunks_data: Dictionary = { } # { "16_24": TerrainChunkData, ... }
var _samplers: Dictionary = { } # { "16_24": HeightfieldSampler, ... }
var _obstacle_indices: Dictionary = { } # { "16_24": SpatialObstacleIndex, ... }
var _nav_map_rid: RID
var _nav_regions: Dictionary = { } # { "16_24": RID, ... }
var _nav_meshes: Dictionary = { } # { "16_24": NavigationMesh, ... }

var _resource_adapter: RefCounted
var _meta_use_case: RefCounted
var _hf_use_case: RefCounted
var _altitude_use_case: RefCounted
var _movement_use_case: RefCounted
var _obstacles_use_case: RefCounted


func _init(p_base_path: String = "res://assets/maps") -> void:
	base_maps_path = p_base_path
	_resource_adapter = ChunkResourceAdapterClass.new(base_maps_path)
	_meta_use_case = LoadChunkMetadataUseCaseClass.new()
	_hf_use_case = LoadServerHeightfieldUseCaseClass.new()
	_altitude_use_case = SampleWorldAltitudeUseCaseClass.new()
	_movement_use_case = ValidatePlayerMovementUseCaseClass.new()
	_obstacles_use_case = LoadServerStaticObstaclesUseCaseClass.new()

	_nav_map_rid = NavigationServer3D.map_create()
	NavigationServer3D.map_set_active(_nav_map_rid, true)
	NavigationServer3D.map_set_cell_size(_nav_map_rid, 1.5)
	NavigationServer3D.map_set_cell_height(_nav_map_rid, 0.5)


func load_server_chunk(chunk_name: String) -> bool:
	var chunk_data = _meta_use_case.execute(chunk_name, _resource_adapter, true)
	if not chunk_data:
		return false

	var sampler = _hf_use_case.execute(chunk_name, _resource_adapter)
	if not sampler:
		return false

	var obstacle_index = _obstacles_use_case.execute(chunk_name, base_maps_path)

	_chunks_data[chunk_name] = chunk_data
	_samplers[chunk_name] = sampler
	if obstacle_index:
		_obstacle_indices[chunk_name] = obstacle_index

	# Registra a NavMesh pré-compilada no mapa de navegação 3D
	var navmesh = _resource_adapter.load_chunk_navmesh(chunk_name)
	if navmesh:
		_nav_meshes[chunk_name] = navmesh
		var region_rid = NavigationServer3D.region_create()
		NavigationServer3D.region_set_map(region_rid, _nav_map_rid)
		var chunk_origin = chunk_data.world_origin
		var xform = Transform3D(Basis(), chunk_origin)
		NavigationServer3D.region_set_transform(region_rid, xform)
		NavigationServer3D.region_set_navigation_mesh(region_rid, navmesh)
		_nav_regions[chunk_name] = region_rid

	return true


func load_all_available_chunks() -> Array[String]:
	var loaded: Array[String] = []
	var available = _resource_adapter.get_available_chunks()
	for c_name in available:
		if load_server_chunk(c_name):
			loaded.append(c_name)
	return loaded


func get_altitude_at(world_x: float, world_z: float) -> Dictionary:
	return _altitude_use_case.execute(world_x, world_z, _chunks_data, _samplers)


func validate_movement(
	from_pos: Vector3,
	to_pos: Vector3,
	delta_time: float = ServerMovementValidatorClass.DEFAULT_DELTA_TIME,
	max_speed: float = ServerMovementValidatorClass.DEFAULT_MAX_SPEED,
	entity_radius: float = ServerMovementValidatorClass.DEFAULT_ENTITY_RADIUS,
) -> Dictionary:
	return _movement_use_case.execute(
		from_pos,
		to_pos,
		_chunks_data,
		_samplers,
		_obstacle_indices,
		delta_time,
		max_speed,
		ServerMovementValidatorClass.DEFAULT_MAX_SLOPE_RATIO,
		entity_radius,
	)


func get_obstacle_index_at(world_x: float, world_z: float) -> RefCounted:
	for c_name in _chunks_data.keys():
		var chunk = _chunks_data[c_name]
		if (
			chunk and chunk.has_method("contains_world_point")
			and chunk.contains_world_point(world_x, world_z)
		):
			return _obstacle_indices.get(c_name, null)
	return null


func get_loaded_chunks() -> Array:
	return _chunks_data.keys()


func find_sampler_at(world_x: float, world_z: float) -> RefCounted:
	for c_name in _chunks_data.keys():
		var chunk = _chunks_data[c_name]
		if (
			chunk and chunk.has_method("contains_world_point")
			and chunk.contains_world_point(world_x, world_z)
		):
			return _samplers.get(c_name, null)
	return null


func get_chunk_name_at(world_x: float, world_z: float) -> String:
	for c_name in _chunks_data.keys():
		var chunk = _chunks_data[c_name]
		if (
			chunk and chunk.has_method("contains_world_point")
			and chunk.contains_world_point(world_x, world_z)
		):
			return c_name
	return ""


func get_nav_map_rid() -> RID:
	return _nav_map_rid


func get_chunk_navmesh(chunk_name: String) -> NavigationMesh:
	return _nav_meshes.get(chunk_name, null)


func is_point_navigable(pos: Vector3, max_dist: float = 1.0) -> bool:
	if not _nav_map_rid.is_valid():
		return true
	var closest = NavigationServer3D.map_get_closest_point(_nav_map_rid, pos)
	return pos.distance_to(closest) <= max_dist


func get_closest_navigable_point(pos: Vector3) -> Vector3:
	if not _nav_map_rid.is_valid():
		return pos
	return NavigationServer3D.map_get_closest_point(_nav_map_rid, pos)


func find_path(from_pos: Vector3, to_pos: Vector3) -> PackedVector3Array:
	if not _nav_map_rid.is_valid():
		return PackedVector3Array([from_pos, to_pos])
	return NavigationServer3D.map_get_path(_nav_map_rid, from_pos, to_pos, true)


func cleanup() -> void:
	for r_rid in _nav_regions.values():
		if r_rid is RID and r_rid.is_valid():
			NavigationServer3D.free_rid(r_rid)
	_nav_regions.clear()
	_nav_meshes.clear()
	if _nav_map_rid.is_valid():
		NavigationServer3D.free_rid(_nav_map_rid)
