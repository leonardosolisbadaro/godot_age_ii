## @file world_chunk_manager.gd
## @path res://src/infrastructure/world_chunk_manager.gd
##
## @description
## Gerenciador central de infraestrutura no cliente responsável pelo ciclo de vida
## e streaming contínuo de chunks visuais de terreno e atores estáticos no mundo.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends Node3D

const ChunkResourceAdapterClass = preload("res://src/adapters/chunk_resource_adapter.gd")
const LoadChunkMetadataUseCaseClass = preload("res://src/use_cases/load_chunk_metadata_use_case.gd")
const StreamWorldChunksUseCaseClass = preload("res://src/use_cases/stream_world_chunks_use_case.gd")
const L2TerrainChunkNodeClass = preload("res://src/infrastructure/l2_terrain_chunk_node.gd")
const StaticMeshChunkNodeClass = preload("res://src/infrastructure/static_mesh_chunk_node.gd")
const OceanPlaneNodeClass = preload("res://src/infrastructure/ocean_plane_node.gd")

var base_maps_path: String = "res://assets/maps"
var view_radius_meters: float = 1200.0

var _known_chunks: Dictionary = {} # { "16_24": TerrainChunkData, ... }
var _active_terrain_nodes: Dictionary = {} # { "16_24": L2TerrainChunkNode, ... }
var _active_mesh_nodes: Dictionary = {} # { "16_24": StaticMeshChunkNode, ... }
var _ocean_node: MeshInstance3D

var _resource_adapter: RefCounted
var _meta_use_case: RefCounted
var _stream_use_case: RefCounted


func _init(p_base_path: String = "res://assets/maps", p_radius: float = 1200.0) -> void:
	base_maps_path = p_base_path
	view_radius_meters = p_radius
	_resource_adapter = ChunkResourceAdapterClass.new(base_maps_path)
	_meta_use_case = LoadChunkMetadataUseCaseClass.new()
	_stream_use_case = StreamWorldChunksUseCaseClass.new()


func register_chunk(chunk_name: String) -> bool:
	if _known_chunks.has(chunk_name):
		return true

	var chunk_data = _meta_use_case.execute(chunk_name, _resource_adapter, true)
	if chunk_data:
		_known_chunks[chunk_name] = chunk_data
		return true
	return false


func update_streaming(avatar_pos: Vector3) -> void:
	var loaded_names = _active_terrain_nodes.keys()
	var stream_res = _stream_use_case.execute(
		avatar_pos,
		view_radius_meters,
		_known_chunks,
		loaded_names
	)

	# 1. Carrega novos chunks no raio de visão
	for c_name in stream_res.get("to_load", []):
		load_chunk(c_name)

	# 2. Descarrega chunks fora do raio de visão
	for c_name in stream_res.get("to_unload", []):
		unload_chunk(c_name)


func load_chunk(chunk_name: String) -> void:
	if _active_terrain_nodes.has(chunk_name):
		return

	# Instancia Terreno Visual
	var terrain_node = L2TerrainChunkNodeClass.new(chunk_name, base_maps_path)
	terrain_node.name = "Terrain_%s" % chunk_name
	var chunk_data = _known_chunks.get(chunk_name)
	if chunk_data:
		terrain_node.position = chunk_data.world_origin
	add_child(terrain_node)
	_active_terrain_nodes[chunk_name] = terrain_node

	# Instancia Atores Estáticos (MultiMesh)
	var mesh_node = StaticMeshChunkNodeClass.new(chunk_name, base_maps_path)
	mesh_node.name = "StaticMeshes_%s" % chunk_name
	add_child(mesh_node)
	_active_mesh_nodes[chunk_name] = mesh_node


func unload_chunk(chunk_name: String) -> void:
	if _active_terrain_nodes.has(chunk_name):
		var t_node = _active_terrain_nodes[chunk_name]
		_active_terrain_nodes.erase(chunk_name)
		t_node.queue_free()

	if _active_mesh_nodes.has(chunk_name):
		var m_node = _active_mesh_nodes[chunk_name]
		_active_mesh_nodes.erase(chunk_name)
		m_node.queue_free()


func setup_ocean(water_level_y: float = -290.0, center: Vector3 = Vector3(-7864.0, 0.0, 18350.0)) -> void:
	if not _ocean_node:
		_ocean_node = OceanPlaneNodeClass.new(water_level_y, Vector2(5000.0, 5000.0), center)
		_ocean_node.name = "OceanPlane"
		add_child(_ocean_node)


func get_active_chunk_count() -> int:
	return _active_terrain_nodes.size()
