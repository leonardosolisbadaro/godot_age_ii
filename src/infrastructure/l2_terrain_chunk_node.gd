## @file l2_terrain_chunk_node.gd
## @path res://src/infrastructure/l2_terrain_chunk_node.gd
##
## @description
## Nó 3D da camada de infraestrutura que encapsula e exibe a geometria visual
## e colisão física de um chunk de terreno no mundo (Lineage II / Godotage II).
##
## @created 2026-08-19
## @updated 2026-08-21
##
## @author Leonardo S. Badaró
extends Node3D

const TerrainShader = preload("res://src/infrastructure/shaders/l2_terrain.gdshader")
const OceanShader = preload("res://src/infrastructure/shaders/ocean_water.gdshader")
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
var _is_built: bool = false


func _init(p_chunk_name: String = "", p_base_path: String = "res://assets/maps") -> void:
	chunk_name = p_chunk_name
	base_maps_path = p_base_path


func _ready() -> void:
	if not chunk_name.is_empty():
		build_chunk_node()


func build_chunk_node() -> void:
	if _is_built:
		return
	_is_built = true

	# 1. Carrega cena visual .glb do chunk via TerrainChunkAdapter
	var adapter = TerrainChunkAdapterClass.new()
	_visual_instance = adapter.load_visual_mesh_node(chunk_name, base_maps_path)
	if _visual_instance:
		add_child(_visual_instance)
		_setup_material_and_textures()
		_setup_physics_collision()
		_setup_local_water_volumes()


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

	var resource_adapter = ChunkResourceAdapterClass.new(base_maps_path)
	var meta = resource_adapter.load_chunk_meta_dict(chunk_name, true)
	var has_holes = meta.get("has_holes", false)
	var hf_bytes = resource_adapter.load_heightfield_bytes(chunk_name)

	# Se não tiver buracos/cavernas e tiver heightfield binário, usa HeightMapShape3D (10x mais leve e instantâneo)
	if not has_holes and not hf_bytes.is_empty():
		var floats = hf_bytes.to_float32_array()
		var grid_res = meta.get("grid_resolution", [256, 256])
		var cols = int(grid_res[0])
		var rows = int(grid_res[1])
		var dims = meta.get("chunk_dimensions_meters", [2621.44, 2621.44])
		var w = float(dims[0])
		var d = float(dims[1])
		var cell_x = w / float(max(1, cols - 1))
		var cell_z = d / float(max(1, rows - 1))

		var hm_shape = HeightMapShape3D.new()
		hm_shape.map_width = cols
		hm_shape.map_depth = rows
		hm_shape.map_data = floats

		_collision_shape.shape = hm_shape
		_collision_shape.scale = Vector3(cell_x, 1.0, cell_z)
	else:
		# Fallback de alta fidelidade para cavernas e terrenos perfurados
		var trimesh_shape = mesh_node.mesh.create_trimesh_shape()
		if trimesh_shape:
			_collision_shape.shape = trimesh_shape

	if _collision_shape.shape:
		_static_body.add_child(_collision_shape)
		add_child(_static_body)


var _water_volume_nodes: Array[MeshInstance3D] = []
var _water_volumes_data: Dictionary = { }


func get_water_volumes_data() -> Dictionary:
	return _water_volumes_data


func get_water_volume_nodes() -> Array[MeshInstance3D]:
	return _water_volume_nodes


func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = _find_first_mesh_instance(child)
		if found:
			return found
	return null


func _setup_local_water_volumes() -> void:
	_water_volume_nodes.clear()
	var resource_adapter = ChunkResourceAdapterClass.new(base_maps_path)
	_water_volumes_data = resource_adapter.load_water_volumes_dict(chunk_name)
	var volumes = _water_volumes_data.get("water_volumes", { })
	if not (volumes is Dictionary):
		return

	for v_name in volumes.keys():
		var v = volumes[v_name]
		if not (v is Dictionary):
			continue
		if v.get("enabled", true) == false or v.get("hidden", false) == true:
			continue

		var surface_y = float(v.get("water_plane_height_m", v.get("surface_y_m", -320.0)))
		var center_arr = v.get("center_m", [0.0, 0.0])
		var size_arr = v.get("size_m", [2621.44, 2621.44])
		var c_x = float(center_arr[0]) if center_arr.size() > 0 else 0.0
		var c_z = float(center_arr[1]) if center_arr.size() > 1 else 0.0
		var s_x = float(size_arr[0]) if size_arr.size() > 0 else 2621.44
		var s_z = float(size_arr[1]) if size_arr.size() > 1 else 2621.44

		# Suporte a expansão para horizonte de oceano
		var ocean_ext = float(v.get("ocean_extension", 0.0))
		s_x += ocean_ext
		s_z += ocean_ext

		var plane = MeshInstance3D.new()
		var p_mesh = PlaneMesh.new()
		p_mesh.size = Vector2(s_x, s_z)
		p_mesh.subdivide_width = 2
		p_mesh.subdivide_depth = 2
		plane.mesh = p_mesh

		var mat = ShaderMaterial.new()
		mat.shader = OceanShader
		plane.material_override = mat

		plane.position = Vector3(c_x, surface_y, c_z)
		plane.name = "WaterVolume_" + str(v.get("name", v_name))
		add_child(plane)
		_water_volume_nodes.append(plane)


func update_water_volume_runtime(volume_name: String, data: Dictionary) -> bool:
	if not _water_volumes_data.has("water_volumes") or not (_water_volumes_data["water_volumes"] is Dictionary):
		_water_volumes_data["water_volumes"] = { }

	var volumes = _water_volumes_data["water_volumes"]
	if not volumes.has(volume_name):
		volumes[volume_name] = { }

	# Atualiza o dicionário em memória
	for k in data.keys():
		volumes[volume_name][k] = data[k]

	var v = volumes[volume_name]
	var surface_y = float(v.get("water_plane_height_m", v.get("surface_y_m", -320.0)))
	var center_arr = v.get("center_m", [0.0, 0.0])
	var size_arr = v.get("size_m", [2621.44, 2621.44])
	var c_x = float(center_arr[0]) if center_arr.size() > 0 else 0.0
	var c_z = float(center_arr[1]) if center_arr.size() > 1 else 0.0
	var s_x = float(size_arr[0]) if size_arr.size() > 0 else 2621.44
	var s_z = float(size_arr[1]) if size_arr.size() > 1 else 2621.44
	var ocean_ext = float(v.get("ocean_extension", 0.0))
	s_x += ocean_ext
	s_z += ocean_ext

	var is_enabled = v.get("enabled", true)

	var node_name = "WaterVolume_" + volume_name
	for plane in _water_volume_nodes:
		if plane and (plane.name == node_name or plane.name == ("WaterVolume_" + str(v.get("name", "")))):
			plane.position = Vector3(c_x, surface_y, c_z)
			if plane.mesh is PlaneMesh:
				(plane.mesh as PlaneMesh).size = Vector2(s_x, s_z)
			plane.visible = is_enabled
			return true

	return false


func get_raw_water_volume_data(volume_name: String) -> Dictionary:
	var path_root = "%s/%s/water_volumes.json" % [base_maps_path, chunk_name]
	if not FileAccess.file_exists(path_root):
		return { }

	var file = FileAccess.open(path_root, FileAccess.READ)
	if not file:
		return { }

	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	if err != OK or not (json.data is Dictionary):
		return { }

	var raw_vols = json.data.get("water_volumes", { })
	if raw_vols is Dictionary and raw_vols.has(volume_name):
		return raw_vols[volume_name]

	return { }


