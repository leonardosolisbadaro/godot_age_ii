## @file l2_terrain_chunk_node.gd
## @path res://src/infrastructure/l2_terrain_chunk_node.gd
##
## @description
## Nó 3D da camada de infraestrutura que encapsula e exibe a geometria visual
## e colisão física de um chunk de terreno no mundo (Lineage II / Godotage II).
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends Node3D

const TerrainShader = preload("res://src/infrastructure/shaders/l2_terrain.gdshader")
const ChunkResourceAdapterClass = preload("res://src/adapters/chunk_resource_adapter.gd")

var chunk_name: String = ""
var base_maps_path: String = "res://assets/maps"

var _visual_instance: Node3D
var _static_body: StaticBody3D
var _collision_shape: CollisionShape3D


func _init(p_chunk_name: String = "", p_base_path: String = "res://assets/maps") -> void:
	chunk_name = p_chunk_name
	base_maps_path = p_base_path


func _ready() -> void:
	if not chunk_name.is_empty():
		build_chunk_node()


func build_chunk_node() -> void:
	# 1. Carrega cena visual .glb do chunk
	var visual_glb_path = "%s/%s/client/%s_visual.glb" % [base_maps_path, chunk_name, chunk_name]
	if ResourceLoader.exists(visual_glb_path):
		var scene_res = load(visual_glb_path)
		if scene_res and scene_res is PackedScene:
			_visual_instance = scene_res.instantiate()
			add_child(_visual_instance)
			_setup_material_and_textures()
			_setup_physics_collision()


func _setup_material_and_textures() -> void:
	if not _visual_instance:
		return

	var mat = ShaderMaterial.new()
	mat.shader = TerrainShader

	var client_dir = "%s/%s/client" % [base_maps_path, chunk_name]

	# Splatmaps
	if ResourceLoader.exists("%s/splatmap_0.png" % client_dir):
		mat.set_shader_parameter("splatmap_0", load("%s/splatmap_0.png" % client_dir))
	if ResourceLoader.exists("%s/splatmap_1.png" % client_dir):
		mat.set_shader_parameter("splatmap_1", load("%s/splatmap_1.png" % client_dir))

	# Textura Base
	if ResourceLoader.exists("%s/textures/layer_0_tex_Base.png" % client_dir):
		mat.set_shader_parameter("tex_base", load("%s/textures/layer_0_tex_Base.png" % client_dir))

	# Aplica o material em todos os MeshInstance3D filhos
	_apply_material_recursive(_visual_instance, mat)


func _apply_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_apply_material_recursive(child, mat)


func _setup_physics_collision() -> void:
	if not _visual_instance:
		return

	var mesh_node: MeshInstance3D = _find_first_mesh_instance(_visual_instance)
	if not mesh_node or not mesh_node.mesh:
		return

	_static_body = StaticBody3D.new()
	_static_body.name = "TerrainStaticBody"

	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "TerrainCollisionShape"

	var trimesh_shape = mesh_node.mesh.create_trimesh_shape()
	if trimesh_shape:
		_collision_shape.shape = trimesh_shape
		_static_body.add_child(_collision_shape)
		add_child(_static_body)


func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = _find_first_mesh_instance(child)
		if found:
			return found
	return null
