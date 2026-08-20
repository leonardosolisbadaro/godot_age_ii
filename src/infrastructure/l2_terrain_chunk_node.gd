## @file l2_terrain_chunk_node.gd
## @path res://src/infrastructure/l2_terrain_chunk_node.gd
##
## @description
## Nó 3D da camada de infraestrutura que encapsula e exibe a geometria visual
## e colisão física de um chunk de terreno no mundo (Lineage II / Godotage II).
##
## @created 2026-08-19
## @updated 2026-08-20
##
## @author Leonardo S. Badaró
extends Node3D

const TerrainShader = preload("res://src/infrastructure/shaders/l2_terrain.gdshader")
const ChunkResourceAdapterClass = preload("res://src/adapters/chunk_resource_adapter.gd")
const TerrainChunkAdapterClass = preload("res://src/adapters/terrain_chunk_adapter.gd")
const RuntimeAssetCacheClass = preload("res://src/infrastructure/runtime_asset_cache.gd")

# ==============================================================================
# CONSTANTES SEMÂNTICAS DE TERRENO
# ==============================================================================

## @const MAX_TERRAIN_LAYERS (int)
## O que: Quantidade máxima de camadas de textura detalhadas por chunk suportadas pelo shader (12 camadas).
## Porque: Limite calibrado para os 3 Splatmaps RGBA (4 canais * 3 = 12 camadas + Base).
const MAX_TERRAIN_LAYERS: int = 12

## @const DEFAULT_UV_SCALE (float)
## O que: Escala UV unitária padrão para camadas de terreno sem override (1.0).
## Porque: Mapeamento textural neutro 1:1.
const DEFAULT_UV_SCALE: float = 1.0

# ==============================================================================
# PROPRIEDADES DO NÓ
# ==============================================================================

var chunk_name: String = ""
var base_maps_path: String = "res://assets/maps"

var _visual_instance: Node3D
var _terrain_material: ShaderMaterial
var _static_body: StaticBody3D
var _collision_shape: CollisionShape3D


func _init(p_chunk_name: String = "", p_base_path: String = "res://assets/maps") -> void:
	chunk_name = p_chunk_name
	base_maps_path = p_base_path


func _ready() -> void:
	if not chunk_name.is_empty():
		build_chunk_node()


func build_chunk_node() -> void:
	# 1. Carrega cena visual .glb do chunk via TerrainChunkAdapter
	var adapter = TerrainChunkAdapterClass.new()
	_visual_instance = adapter.load_visual_mesh_node(chunk_name, base_maps_path)
	if _visual_instance:
		add_child(_visual_instance)
		_setup_material_and_textures()
		_setup_physics_collision()


func set_wireframe_enabled(enabled: bool) -> void:
	if _terrain_material:
		_terrain_material.set_shader_parameter("show_wireframe", enabled)


func _setup_material_and_textures() -> void:
	if not _visual_instance:
		return

	var mat = ShaderMaterial.new()
	mat.shader = TerrainShader
	_terrain_material = mat

	var client_dir = "%s/%s/client" % [base_maps_path, chunk_name]

	# 1. Carrega Splatmaps 0, 1 e 2
	var splat0 = _load_texture("%s/splatmap_0.png" % client_dir)
	if splat0:
		mat.set_shader_parameter("splatmap_0", splat0)
	var splat1 = _load_texture("%s/splatmap_1.png" % client_dir)
	if splat1:
		mat.set_shader_parameter("splatmap_1", splat1)
	var splat2 = _load_texture("%s/splatmap_2.png" % client_dir)
	if splat2:
		mat.set_shader_parameter("splatmap_2", splat2)

	# 2. Textura Base
	var base_tex = _load_texture("%s/textures/layer_0_tex_Base.png" % client_dir)
	if base_tex:
		mat.set_shader_parameter("tex_base", base_tex)

	# 3. Carrega metadados do terrain_recipe.json para escalas e pans precisos
	var resource_adapter = ChunkResourceAdapterClass.new(base_maps_path)
	var recipe_dict = resource_adapter.load_chunk_meta_dict(chunk_name, false)
	var layers_info = recipe_dict.get("layers", [])
	var layer_map: Dictionary = { }
	for l in layers_info:
		if l is Dictionary and l.has("layer_index"):
			layer_map[int(l["layer_index"])] = l

	# 4. Carrega Camadas 1 a MAX_TERRAIN_LAYERS
	var da = DirAccess.open("%s/textures" % client_dir)
	if da:
		da.list_dir_begin()
		var file_name = da.get_next()
		while not file_name.is_empty():
			if not da.current_is_dir() and file_name.ends_with(".png"):
				for i in range(1, MAX_TERRAIN_LAYERS + 1):
					if file_name.begins_with("layer_%d_" % i):
						var tex_path = "%s/textures/%s" % [client_dir, file_name]
						var layer_tex = _load_texture(tex_path)
						if layer_tex:
							mat.set_shader_parameter("has_layer_%d" % i, true)
							mat.set_shader_parameter("tex_layer_%d" % i, layer_tex)
							if layer_map.has(i):
								var l_data = layer_map[i]
								var u_sc = float(l_data.get("u_scale", DEFAULT_UV_SCALE))
								var v_sc = float(l_data.get("v_scale", DEFAULT_UV_SCALE))
								mat.set_shader_parameter("uv_scale_%d" % i, Vector2(u_sc, v_sc))
			file_name = da.get_next()

	# Aplica o material em todos os MeshInstance3D filhos
	_apply_material_recursive(_visual_instance, mat)


func _load_texture(path: String) -> Texture2D:
	return RuntimeAssetCacheClass.get_or_load_texture(path, true)


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
