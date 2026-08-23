## @file static_mesh_chunk_node.gd
## @path res://src/client/infrastructure/static_mesh_chunk_node.gd
##
## @description
## Nó 3D da camada de apresentação/infraestrutura que carrega e agrupa os atores
## estáticos do chunk (árvores, rochas, construções) renderizando em lote com MultiMeshInstance3D.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
class_name StaticMeshChunkNode
extends Node3D

# ==============================================================================
# DEPENDÊNCIAS PRELOAD
# ==============================================================================

const ChunkResourceAdapterClass = preload("res://src/client/adapters/chunk_resource_adapter.gd")

# ==============================================================================
# PROPRIEDADES DO NÓ
# ==============================================================================

var chunk_name: String = ""
var base_maps_path: String = "res://assets/maps"

var _multimesh_instances: Array[MultiMeshInstance3D] = []
var _material_recipes: Dictionary = { }
var _material_cache: Dictionary = { }
var _is_built: bool = false


func _init(p_chunk_name: String = "", p_base_path: String = "res://assets/maps") -> void:
	chunk_name = p_chunk_name
	base_maps_path = p_base_path


func _ready() -> void:
	if not chunk_name.is_empty() and not _is_built:
		build_static_meshes()


func _exit_tree() -> void:
	for mm in _multimesh_instances:
		if mm != null and is_instance_valid(mm):
			mm.queue_free()
	_multimesh_instances.clear()
	_material_cache.clear()


## Carrega atores de chunk_static_actors.json e agrupa por modelo para MultiMeshInstance3D.
func build_static_meshes() -> void:
	if _is_built or chunk_name.is_empty():
		return
	_is_built = true

	_material_recipes = ChunkResourceAdapterClass.load_material_recipes(chunk_name, base_maps_path)

	var actors = ChunkResourceAdapterClass.load_static_actors(chunk_name, base_maps_path)
	if actors.is_empty():
		return

	# Agrupa instâncias por mesh_path
	var groups: Dictionary = { } # { "res://assets/models/...": [Transform3D, ...] }
	for actor in actors:
		var mesh_path = str(actor.get("mesh_path", ""))
		if mesh_path.is_empty():
			continue

		var actor_transform = _parse_actor_transform(actor)
		if not groups.has(mesh_path):
			groups[mesh_path] = []
		groups[mesh_path].append(actor_transform)

	# Cria os nós MultiMeshInstance3D para cada modelo
	for m_path in groups.keys():
		var mesh_res = _load_mesh(m_path)
		if mesh_res == null:
			continue

		var transforms: Array = groups[m_path]
		var count = transforms.size()
		if count == 0:
			continue

		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh_res
		mm.instance_count = count

		for i in range(count):
			mm.set_instance_transform(i, transforms[i])

		var mm_instance = MultiMeshInstance3D.new()
		mm_instance.multimesh = mm
		mm_instance.name = "MultiMesh_%s" % m_path.get_file().get_basename()
		add_child(mm_instance)
		_multimesh_instances.append(mm_instance)


func _parse_actor_transform(actor_dict: Dictionary) -> Transform3D:
	var pos = Vector3.ZERO
	if actor_dict.has("position") and actor_dict["position"] is Array:
		var p_arr = actor_dict["position"]
		if p_arr.size() >= 3:
			pos = Vector3(float(p_arr[0]), float(p_arr[1]), float(p_arr[2]))

	var scale_vec = Vector3.ONE
	if actor_dict.has("scale") and actor_dict["scale"] is Array:
		var s_arr = actor_dict["scale"]
		if s_arr.size() >= 3:
			scale_vec = Vector3(float(s_arr[0]), float(s_arr[1]), float(s_arr[2]))

	var rot_rad = Vector3.ZERO
	if actor_dict.has("rotation_rad") and actor_dict["rotation_rad"] is Array:
		var r_arr = actor_dict["rotation_rad"]
		if r_arr.size() >= 3:
			rot_rad = Vector3(float(r_arr[0]), float(r_arr[1]), float(r_arr[2]))

	var actor_basis = Basis.from_euler(rot_rad).scaled(scale_vec)
	return Transform3D(actor_basis, pos)


func _load_mesh(path: String) -> Mesh:
	if not ResourceLoader.exists(path):
		return null
	var res = load(path)
	var raw_mesh: Mesh = null
	if res is Mesh:
		raw_mesh = res
	elif res is PackedScene:
		var scene = res.instantiate()
		if scene is MeshInstance3D:
			raw_mesh = scene.mesh
		else:
			for child in scene.get_children():
				if child is MeshInstance3D and child.mesh != null:
					raw_mesh = child.mesh
					break
		scene.queue_free()

	if raw_mesh == null:
		return null

	var mesh_dupe = raw_mesh.duplicate()
	_apply_materials_to_mesh(mesh_dupe, path)
	return mesh_dupe


func _apply_materials_to_mesh(mesh: Mesh, model_path: String) -> void:
	var surf_count = mesh.get_surface_count()
	for surf_idx in range(surf_count):
		var orig_mat = mesh.surface_get_material(surf_idx)
		var mat_name = ""
		if orig_mat != null:
			mat_name = orig_mat.resource_name if not orig_mat.resource_name.is_empty() else orig_mat.name

		var mat = _get_or_create_material(mat_name, model_path)
		if mat != null:
			mesh.surface_set_material(surf_idx, mat)


func _get_or_create_material(mat_name: String, model_path: String) -> Material:
	var clean_name = mat_name.strip_edges().to_lower().replace(" ", "").replace("-", "_")
	if clean_name.is_empty():
		clean_name = model_path.get_file().get_basename().to_lower()

	if _material_cache.has(clean_name):
		return _material_cache[clean_name]

	var name_variants = [clean_name]
	for suf in ["_1", "_2", "_3", "_0", "_4", "_5"]:
		if clean_name.ends_with(suf):
			name_variants.append(clean_name.substr(0, clean_name.length() - suf.length()))

	# 1. Procura em _material_recipes
	var recipe: Dictionary = { }
	for v in name_variants:
		if _material_recipes.has(v):
			recipe = _material_recipes[v]
			break
		for k in _material_recipes.keys():
			var k_clean = k.to_lower().replace(" ", "").replace("-", "_")
			if k_clean == v or k_clean.ends_with("." + v) or k_clean.replace(".", "_") == v:
				recipe = _material_recipes[k]
				break
		if not recipe.is_empty():
			break

	# 2. Resolução de Textura
	var diff_path = recipe.get("diffuse_texture", "")
	var real_tex_path = ""
	if diff_path and not str(diff_path).is_empty():
		real_tex_path = ChunkResourceAdapterClass.resolve_texture_path(str(diff_path))

	if real_tex_path.is_empty():
		for v in name_variants:
			real_tex_path = ChunkResourceAdapterClass.resolve_texture_path(v)
			if not real_tex_path.is_empty():
				break

	if real_tex_path.is_empty():
		var model_name = model_path.get_file().get_basename().to_lower()
		real_tex_path = ChunkResourceAdapterClass.resolve_texture_path(model_name)

	var tex: Texture2D = null
	if not real_tex_path.is_empty() and ResourceLoader.exists(real_tex_path):
		tex = load(real_tex_path)

	# 3. Detecção de Folhagens e Parâmetros PBR
	var is_foliage = false
	var is_two_sided = bool(recipe.get("two_sided", false))
	for v in name_variants:
		if (
			"leaf" in v or "leaves" in v or "branch" in v or "tree" in v
			or "grass" in v or "flower" in v or "fern" in v or "ivy" in v
			or "plant" in v or "flora" in v or "weed" in v or "foliage" in v
		):
			is_foliage = true
			is_two_sided = true
			break
		elif (
			"banner" in v or "flag" in v or "cloth" in v or "tent" in v or "fence" in v
			or "curtain" in v or "rope" in v or "chain" in v or "deco" in v or "bone" in v
		):
			is_two_sided = true
			break

	if not tex:
		var fallback_mat = StandardMaterial3D.new()
		fallback_mat.albedo_color = Color(0.8, 0.78, 0.75, 1.0)
		fallback_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_material_cache[clean_name] = fallback_mat
		return fallback_mat

	var std_mat = StandardMaterial3D.new()
	std_mat.albedo_texture = tex
	std_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	std_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var blend_mode = str(recipe.get("alpha_blend_mode", "Opaque"))
	if is_foliage or blend_mode in ["AlphaTest", "AlphaBlend", "Masked"] or "leaf" in clean_name:
		std_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		std_mat.alpha_scissor_threshold = float(recipe.get("alpha_test_threshold", 0.5))
		std_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		std_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
		std_mat.roughness = 0.8

	_material_cache[clean_name] = std_mat
	return std_mat
