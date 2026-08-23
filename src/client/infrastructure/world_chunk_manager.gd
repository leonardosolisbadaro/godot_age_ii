## @file world_chunk_manager.gd
## @path res://src/client/infrastructure/world_chunk_manager.gd
##
## @description
## Gerenciador central de streaming e ciclo de vida de chunks no cliente.
## Orquestra o carregamento, posicionamento no espaco de mundo e descarregamento
## continuo de terrenos (L2TerrainChunkNode), malhas estaticas (StaticMeshChunkNode)
## e corpos d'agua (WaterChunkNode) alinhados na grade precisa de Lineage II (2621.44m).
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
class_name WorldChunkManager
extends Node3D

# ==============================================================================
# DEPENDÊNCIAS PRELOAD
# ==============================================================================

const L2TerrainChunkNodeClass = preload("res://src/client/infrastructure/l2_terrain_chunk_node.gd")
const StaticMeshChunkNodeClass = preload(
	"res://src/client/infrastructure/static_mesh_chunk_node.gd"
)
const WaterChunkNodeClass = preload("res://src/client/infrastructure/water_chunk_node.gd")
const ChunkResourceAdapterClass = preload("res://src/client/adapters/chunk_resource_adapter.gd")
const CalculateActiveChunksUseCaseClass = preload(
	"res://src/core/use_cases/calculate_active_chunks_use_case.gd"
)
const ScaleConverterClass = preload("res://src/core/domain/scale_converter.gd")

# ==============================================================================
# CONFIGURAÇÃO DE STREAMING
# ==============================================================================

@export var streaming_radius_chunks: int = 1
@export var base_maps_path: String = "res://assets/maps"

var _active_terrain_chunks: Dictionary = { } # { "16_24": L2TerrainChunkNode }
var _active_static_mesh_chunks: Dictionary = { } # { "16_24": StaticMeshChunkNode }
var _active_water_chunks: Dictionary = { } # { "16_24": WaterChunkNode }
var _loaded_coords: Array[Vector2i] = []
var _available_chunks_set: Dictionary = { }

var _sun_light: DirectionalLight3D
var _world_environment: WorldEnvironment


func _ready() -> void:
	_init_lighting_and_environment()
	var available = ChunkResourceAdapterClass.get_available_chunks(base_maps_path)
	for c_name in available:
		_available_chunks_set[c_name] = true


func _exit_tree() -> void:
	for c_name in _active_terrain_chunks.keys():
		var t_node = _active_terrain_chunks[c_name]
		if t_node != null and is_instance_valid(t_node):
			t_node.free()
	for c_name in _active_static_mesh_chunks.keys():
		var m_node = _active_static_mesh_chunks[c_name]
		if m_node != null and is_instance_valid(m_node):
			m_node.free()
	for c_name in _active_water_chunks.keys():
		var w_node = _active_water_chunks[c_name]
		if w_node != null and is_instance_valid(w_node):
			w_node.free()


## Atualiza o streaming contínuo baseado na posição tridimensional de observação.
func update_streaming(focal_pos: Vector3) -> void:
	var result = CalculateActiveChunksUseCaseClass.execute(
		focal_pos,
		streaming_radius_chunks,
		_loaded_coords,
	)

	# 1. Carrega novos chunks
	for coord in result.to_load:
		var c_name = ScaleConverterClass.chunk_coords_to_name(coord)
		if _available_chunks_set.has(c_name):
			load_chunk(c_name)

	# 2. Descarrega chunks fora do raio
	for coord in result.to_unload:
		var c_name = ScaleConverterClass.chunk_coords_to_name(coord)
		unload_chunk(c_name)


## Carrega e instancia no mundo 3D um chunk de terreno, malhas e seus corpos d'água.
func load_chunk(chunk_name: String) -> bool:
	if _active_terrain_chunks.has(chunk_name):
		return true

	var coords = ScaleConverterClass.chunk_name_to_coords(chunk_name)
	var origin_meters = ScaleConverterClass.chunk_coords_to_world_origin_meters(coords)

	# 1. Cria nó de terreno
	var terrain_node = L2TerrainChunkNodeClass.new(chunk_name, base_maps_path)
	terrain_node.name = "Terrain_%s" % chunk_name
	terrain_node.position = origin_meters
	add_child(terrain_node)
	_active_terrain_chunks[chunk_name] = terrain_node

	# 2. Cria nó de malhas estáticas (MultiMesh) posicionado na origem global do mundo
	var static_mesh_node = StaticMeshChunkNodeClass.new(chunk_name, base_maps_path)
	static_mesh_node.name = "StaticMeshes_%s" % chunk_name
	static_mesh_node.position = Vector3.ZERO
	add_child(static_mesh_node)
	_active_static_mesh_chunks[chunk_name] = static_mesh_node

	# 3. Cria nó de corpos d'água
	var water_node = WaterChunkNodeClass.new(chunk_name, base_maps_path)
	water_node.name = "Water_%s" % chunk_name
	water_node.position = origin_meters
	add_child(water_node)
	_active_water_chunks[chunk_name] = water_node

	_loaded_coords.append(coords)

	# 4. Aplica parâmetros de iluminação do chunk
	_apply_environment(chunk_name)
	return true


## Descarrega da memória e remove da árvore de cenas um chunk ativo.
func unload_chunk(chunk_name: String) -> void:
	if not _active_terrain_chunks.has(chunk_name):
		return

	var terrain_node = _active_terrain_chunks[chunk_name]
	_active_terrain_chunks.erase(chunk_name)
	if terrain_node != null and is_instance_valid(terrain_node):
		terrain_node.free()

	if _active_static_mesh_chunks.has(chunk_name):
		var mesh_node = _active_static_mesh_chunks[chunk_name]
		_active_static_mesh_chunks.erase(chunk_name)
		if mesh_node != null and is_instance_valid(mesh_node):
			mesh_node.free()

	if _active_water_chunks.has(chunk_name):
		var water_node = _active_water_chunks[chunk_name]
		_active_water_chunks.erase(chunk_name)
		if water_node != null and is_instance_valid(water_node):
			water_node.free()

	var coords = ScaleConverterClass.chunk_name_to_coords(chunk_name)
	_loaded_coords.erase(coords)


func get_active_chunk_names() -> Array[String]:
	var names: Array[String] = []
	for k in _active_terrain_chunks.keys():
		names.append(k)
	return names


func get_active_terrain_chunks() -> Dictionary:
	return _active_terrain_chunks


func _init_lighting_and_environment() -> void:
	_sun_light = DirectionalLight3D.new()
	_sun_light.name = "WorldSunLight"
	_sun_light.shadow_enabled = true
	_sun_light.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	add_child(_sun_light)

	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.68, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.38, 0.45)

	_world_environment = WorldEnvironment.new()
	_world_environment.name = "WorldEnv"
	_world_environment.environment = env
	add_child(_world_environment)


func _apply_environment(chunk_name: String) -> void:
	var env_data = ChunkResourceAdapterClass.load_environment_zone(chunk_name, base_maps_path)
	if _sun_light != null and env_data != null:
		_sun_light.light_color = env_data.sun_color
	if _world_environment != null and _world_environment.environment != null and env_data != null:
		_world_environment.environment.ambient_light_color = env_data.ambient_color
