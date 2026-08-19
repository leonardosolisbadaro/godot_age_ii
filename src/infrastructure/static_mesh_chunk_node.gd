## @file static_mesh_chunk_node.gd
## @path res://src/infrastructure/static_mesh_chunk_node.gd
##
## @description
## Nó 3D da camada de infraestrutura que carrega, agrupa e renderiza os atores
## estáticos de um chunk em lote de alta performance via MultiMeshInstance3D.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends Node3D

const ChunkResourceAdapterClass = preload("res://src/adapters/chunk_resource_adapter.gd")
const StaticMeshInstanceAdapterClass = preload("res://src/adapters/static_mesh_instance_adapter.gd")

var chunk_name: String = ""
var base_maps_path: String = "res://assets/maps"

var _multimesh_nodes: Array = []


func _init(p_chunk_name: String = "", p_base_path: String = "res://assets/maps") -> void:
	chunk_name = p_chunk_name
	base_maps_path = p_base_path


func _ready() -> void:
	if not chunk_name.is_empty():
		build_static_meshes()


func build_static_meshes() -> void:
	var resource_adapter = ChunkResourceAdapterClass.new(base_maps_path)
	var actors_raw = resource_adapter.load_static_actors_array(chunk_name, false)
	if actors_raw.is_empty():
		return

	var inst_adapter = StaticMeshInstanceAdapterClass.new()
	var parsed_instances = inst_adapter.parse_actor_dictionaries(actors_raw)
	var groups = inst_adapter.group_by_mesh_path(parsed_instances)

	for mesh_path in groups.keys():
		var instances = groups[mesh_path]
		var mesh = _load_mesh_resource(mesh_path)
		if mesh:
			var mm_node = inst_adapter.create_multimesh_instance(mesh, instances)
			if mm_node:
				_multimesh_nodes.append(mm_node)
				add_child(mm_node)


func _load_mesh_resource(mesh_path: String) -> Mesh:
	if not ResourceLoader.exists(mesh_path):
		return null

	var scene_res = load(mesh_path)
	if scene_res is PackedScene:
		var temp_node = scene_res.instantiate()
		var mesh = _extract_mesh_from_node(temp_node)
		temp_node.free()
		return mesh
	elif scene_res is Mesh:
		return scene_res

	return null


func _extract_mesh_from_node(node: Node) -> Mesh:
	if node is MeshInstance3D and node.mesh:
		return node.mesh
	for child in node.get_children():
		var m = _extract_mesh_from_node(child)
		if m:
			return m
	return null


func get_multimesh_count() -> int:
	return _multimesh_nodes.size()
