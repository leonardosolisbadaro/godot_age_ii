## @file world_chunk_manager.gd
## @path res://src/infrastructure/world_chunk_manager.gd
##
## @description
## Gerenciador central de infraestrutura no cliente responsável pelo ciclo de vida
## e streaming contínuo de chunks visuais de terreno e atores estáticos no mundo.
##
## @created 2026-08-19
## @updated 2026-08-20
##
## @author Leonardo S. Badaró
extends Node3D

const ChunkResourceAdapterClass = preload("res://src/adapters/chunk_resource_adapter.gd")
const LoadChunkMetadataUseCaseClass = preload("res://src/use_cases/load_chunk_metadata_use_case.gd")
const StreamWorldChunksUseCaseClass = preload("res://src/use_cases/stream_world_chunks_use_case.gd")
const L2TerrainChunkNodeClass = preload("res://src/infrastructure/l2_terrain_chunk_node.gd")
const StaticMeshChunkNodeClass = preload("res://src/infrastructure/static_mesh_chunk_node.gd")
const OceanPlaneNodeClass = preload("res://src/infrastructure/ocean_plane_node.gd")

# ==============================================================================
# CONSTANTES SEMÂNTICAS DE GERENCIAMENTO DE MUNDO
# ==============================================================================

## @const DEFAULT_VIEW_RADIUS_METERS (float)
## O que: Raio de visão de streaming padrão em metros (1200.0m).
## Porque: Distância balanceada de carregamento para visualização e performance.
const DEFAULT_VIEW_RADIUS_METERS: float = 1200.0

## @const INFINITE_RAY_DISTANCE (float)
## O que: Distância infinita sentinela para testes de interseção de raios (999999.0m).
## Porque: Inicializador de busca de menor distância.
const INFINITE_RAY_DISTANCE: float = 999999.0

## @const DEFAULT_OCEAN_LEVEL_Y (float)
## O que: Cota de elevação mundial padrão do nível do oceano (-290.0m).
## Porque: Altura de referência das águas costeiras de Talking Island.
const DEFAULT_OCEAN_LEVEL_Y: float = -290.0

## @const DEFAULT_OCEAN_EXTENTS (Vector2)
## O que: Dimensões métricas do plano de oceano (5000.0m x 5000.0m).
## Porque: Cobre o arquipélago completo.
const DEFAULT_OCEAN_EXTENTS: Vector2 = Vector2(5000.0, 5000.0)

## @const DEFAULT_OCEAN_CENTER (Vector3)
## O que: Posição central mundial do oceano (X=-7864.0m, Y=0.0m, Z=18350.0m).
## Porque: Ponto médio do arquipélago de Talking Island.
const DEFAULT_OCEAN_CENTER: Vector3 = Vector3(-7864.0, 0.0, 18350.0)

# ==============================================================================
# PROPRIEDADES DO GERENCIADOR
# ==============================================================================

var base_maps_path: String = "res://assets/maps"
var view_radius_meters: float = DEFAULT_VIEW_RADIUS_METERS

var _known_chunks: Dictionary = { } # { "16_24": TerrainChunkData, ... }
var _active_terrain_nodes: Dictionary = { } # { "16_24": L2TerrainChunkNode, ... }
var _active_mesh_nodes: Dictionary = { } # { "16_24": StaticMeshChunkNode, ... }
var _loading_chunks: Dictionary = { } # { "16_24": true, ... }
var _ocean_node: MeshInstance3D

var _resource_adapter: RefCounted
var _meta_use_case: RefCounted
var _stream_use_case: RefCounted


func _init(p_base_path: String = "res://assets/maps", p_radius: float = DEFAULT_VIEW_RADIUS_METERS) -> void:
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


func register_available_chunks() -> Array[String]:
	var registered: Array[String] = []
	var available = _resource_adapter.get_available_chunks()
	for c_name in available:
		if register_chunk(c_name):
			registered.append(c_name)
	return registered


func update_streaming(avatar_pos: Vector3, async: bool = false) -> void:
	var loaded_names = _active_terrain_nodes.keys()
	var stream_res = _stream_use_case.execute(
		avatar_pos,
		view_radius_meters,
		_known_chunks,
		loaded_names,
	)

	# 1. Carrega novos chunks no raio de visão
	for c_name in stream_res.get("to_load", []):
		load_chunk(c_name, async)

	# 2. Descarrega chunks fora do raio de visão
	for c_name in stream_res.get("to_unload", []):
		unload_chunk(c_name)


func load_chunk(chunk_name: String, async: bool = false) -> void:
	if _active_terrain_nodes.has(chunk_name) or _loading_chunks.has(chunk_name):
		return

	if async:
		_loading_chunks[chunk_name] = true
		WorkerThreadPool.add_task(_thread_load_chunk.bind(chunk_name))
		return

	# Carregamento síncrono imediato
	_build_and_attach_chunk_nodes(chunk_name)


func _thread_load_chunk(chunk_name: String) -> void:
	var terrain_node = L2TerrainChunkNodeClass.new(chunk_name, base_maps_path)
	terrain_node.build_chunk_node()

	var mesh_node = StaticMeshChunkNodeClass.new(chunk_name, base_maps_path)
	mesh_node.build_static_meshes()

	call_deferred("_on_chunk_background_loaded", chunk_name, terrain_node, mesh_node)


func _on_chunk_background_loaded(chunk_name: String, terrain_node: Node3D, mesh_node: Node3D) -> void:
	_loading_chunks.erase(chunk_name)

	if _active_terrain_nodes.has(chunk_name):
		if terrain_node:
			terrain_node.queue_free()
		if mesh_node:
			mesh_node.queue_free()
		return

	# Anexa terreno na cena
	if terrain_node:
		terrain_node.name = "Terrain_%s" % chunk_name
		var chunk_data = _known_chunks.get(chunk_name)
		if chunk_data:
			terrain_node.position = chunk_data.world_origin
		add_child(terrain_node)
		_active_terrain_nodes[chunk_name] = terrain_node

	# Anexa atores estáticos na cena
	if mesh_node:
		mesh_node.name = "StaticMeshes_%s" % chunk_name
		add_child(mesh_node)
		_active_mesh_nodes[chunk_name] = mesh_node


func _build_and_attach_chunk_nodes(chunk_name: String) -> void:
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
	_loading_chunks.erase(chunk_name)

	if _active_terrain_nodes.has(chunk_name):
		var t_node = _active_terrain_nodes[chunk_name]
		_active_terrain_nodes.erase(chunk_name)
		t_node.queue_free()

	if _active_mesh_nodes.has(chunk_name):
		var m_node = _active_mesh_nodes[chunk_name]
		_active_mesh_nodes.erase(chunk_name)
		m_node.queue_free()


func setup_ocean(
	water_level_y: float = DEFAULT_OCEAN_LEVEL_Y,
	center: Vector3 = DEFAULT_OCEAN_CENTER,
) -> void:
	if not _ocean_node:
		_ocean_node = OceanPlaneNodeClass.new(water_level_y, DEFAULT_OCEAN_EXTENTS, center)
		_ocean_node.name = "OceanPlane"
		add_child(_ocean_node)


func set_wireframe_enabled(enabled: bool) -> void:
	for t_node in _active_terrain_nodes.values():
		if t_node and t_node.has_method("set_wireframe_enabled"):
			t_node.set_wireframe_enabled(enabled)


func inspect_object_at_ray(ray_origin: Vector3, ray_dir: Vector3) -> Dictionary:
	var closest_hit: Dictionary = { }
	var min_dist: float = INFINITE_RAY_DISTANCE

	for m_node in _active_mesh_nodes.values():
		if m_node and m_node.has_method("find_actor_under_ray"):
			var hit = m_node.find_actor_under_ray(ray_origin, ray_dir)
			if hit.get("found", false):
				var d = float(hit.get("distance", INFINITE_RAY_DISTANCE))
				if d < min_dist:
					min_dist = d
					closest_hit = hit

	return closest_hit


func get_active_chunk_count() -> int:
	return _active_terrain_nodes.size()
