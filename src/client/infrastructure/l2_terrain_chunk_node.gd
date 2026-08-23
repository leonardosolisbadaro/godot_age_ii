## @file l2_terrain_chunk_node.gd
## @path res://src/client/infrastructure/l2_terrain_chunk_node.gd
##
## @description
## Nó 3D da camada de apresentação/infraestrutura que carrega, configura e exibe
## a malha visual e shader multi-camada (até 12 texturas) de um chunk de terreno de Lineage II.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
class_name L2TerrainChunkNode
extends Node3D

# ==============================================================================
# DEPENDÊNCIAS PRELOAD
# ==============================================================================

const TerrainShader = preload("res://src/client/infrastructure/shaders/l2_terrain.gdshader")
const ChunkResourceAdapterClass = preload("res://src/client/adapters/chunk_resource_adapter.gd")
const ScaleConverterClass = preload("res://src/core/domain/scale_converter.gd")

# ==============================================================================
# CONSTANTES DE SHADER E TEXTURAS
# ==============================================================================

const MAX_TERRAIN_LAYERS: int = 12

# ==============================================================================
# PROPRIEDADES DO CHUNK
# ==============================================================================

var chunk_name: String = ""
var base_maps_path: String = "res://assets/maps"

var _visual_instance: Node3D
var _terrain_material: ShaderMaterial
var _static_body: StaticBody3D
var _is_built: bool = false


func _init(p_chunk_name: String = "", p_base_path: String = "res://assets/maps") -> void:
	chunk_name = p_chunk_name
	base_maps_path = p_base_path


func _ready() -> void:
	if not chunk_name.is_empty() and not _is_built:
		build_chunk_node()


## Constrói a geometria visual, material multi-camada e colisão física do chunk.
func build_chunk_node() -> void:
	if _is_built or chunk_name.is_empty():
		return
	_is_built = true

	var visual_glb_path = "%s/%s/client/%s_visual.glb" % [base_maps_path, chunk_name, chunk_name]
	if ResourceLoader.exists(visual_glb_path):
		var glb_scene = load(visual_glb_path) as PackedScene
		if glb_scene != null:
			_visual_instance = glb_scene.instantiate() as Node3D
			if _visual_instance != null:
				add_child(_visual_instance)
				_setup_material_and_textures()

	_setup_collision()


## Habilita ou desabilita visualização de wireframe de terreno em tempo real.
func set_wireframe_enabled(enabled: bool) -> void:
	if _terrain_material != null:
		_terrain_material.set_shader_parameter("show_wireframe", enabled)


func _setup_material_and_textures() -> void:
	if _visual_instance == null:
		return

	var mat = ShaderMaterial.new()
	mat.shader = TerrainShader
	_terrain_material = mat

	var client_dir = "%s/%s/client" % [base_maps_path, chunk_name]

	# 1. Carrega Splatmaps 0, 1 e 2
	for i in range(3):
		var splat_path = "%s/splatmap_%d.png" % [client_dir, i]
		if ResourceLoader.exists(splat_path):
			var splat_tex = load(splat_path) as Texture2D
			if splat_tex != null:
				mat.set_shader_parameter("splatmap_%d" % i, splat_tex)

	# 2. Textura Base (Camada 0)
	var base_tex_path = "%s/textures/layer_0_tex_Base.png" % client_dir
	if ResourceLoader.exists(base_tex_path):
		var base_tex = load(base_tex_path) as Texture2D
		if base_tex != null:
			mat.set_shader_parameter("tex_base", base_tex)

	# 3. Carrega Camadas 1 a 12 de texturas
	var textures_dir = "%s/textures" % client_dir
	var da = DirAccess.open(textures_dir)
	if da != null:
		da.list_dir_begin()
		var file_name = da.get_next()
		while not file_name.is_empty():
			if not da.current_is_dir() and file_name.ends_with(".png"):
				for i in range(1, MAX_TERRAIN_LAYERS + 1):
					var prefix = "layer_%d_" % i
					if file_name.begins_with(prefix):
						var tex_path = "%s/%s" % [textures_dir, file_name]
						var layer_tex = load(tex_path) as Texture2D
						if layer_tex != null:
							mat.set_shader_parameter("tex_layer_%d" % i, layer_tex)
							mat.set_shader_parameter("has_layer_%d" % i, true)
						break
			file_name = da.get_next()
		da.list_dir_end()

	# Aplica o material em todas as MeshInstance3Ds filhas
	_apply_material_recursive(_visual_instance, mat)


func _apply_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_apply_material_recursive(child, mat)


func _setup_collision() -> void:
	if _visual_instance == null:
		return

	var mesh_node = _find_first_mesh_instance(_visual_instance)
	if mesh_node != null and mesh_node.mesh != null:
		var trimesh_shape = mesh_node.mesh.create_trimesh_shape()
		if trimesh_shape != null:
			_static_body = StaticBody3D.new()
			_static_body.name = "TerrainStaticBody"
			var col_shape = CollisionShape3D.new()
			col_shape.name = "TerrainCollisionShape"
			col_shape.shape = trimesh_shape
			_static_body.add_child(col_shape)
			add_child(_static_body)


func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = _find_first_mesh_instance(child)
		if found != null:
			return found
	return null
