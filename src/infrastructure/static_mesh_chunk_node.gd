## @file static_mesh_chunk_node.gd
## @path res://src/infrastructure/static_mesh_chunk_node.gd
##
## @description
## Nó 3D da camada de infraestrutura que carrega, agrupa e renderiza os atores
## estáticos de um chunk em lote de alta performance via MultiMeshInstance3D.
##
## @created 2026-08-19
## @updated 2026-08-20
##
## @author Leonardo S. Badaró
extends Node3D

const ChunkResourceAdapterClass = preload("res://src/adapters/chunk_resource_adapter.gd")
const StaticMeshInstanceAdapterClass = preload("res://src/adapters/static_mesh_instance_adapter.gd")
const RuntimeAssetCacheClass = preload("res://src/infrastructure/runtime_asset_cache.gd")

# ==============================================================================
# CONSTANTES SEMÂNTICAS DE STATIC MESHES
# ==============================================================================

## @const AABB_RAY_GROWTH_MARGIN (float)
## O que: Margem de expansão em metros aplicada ao AABB para teste de raio do mouse (2.0m).
## Porque: Facilita a seleção e inspeção de objetos finos como postes e cercas.
const AABB_RAY_GROWTH_MARGIN: float = 2.0

## @const DEFAULT_ALPHA_SCISSOR_THRESHOLD (float)
## O que: Limiar padrão de corte alfa para materiais de folhagem e vegetação (0.35).
## Porque: Proporciona folhagens nítidas sem bordas escuras.
const DEFAULT_ALPHA_SCISSOR_THRESHOLD: float = 0.35

## @const FOLIAGE_ROUGHNESS (float)
## O que: Rugosidade padrão para materiais de vegetação (0.85).
## Porque: Reduz reflexos especulares plásticos em folhas e galhos.
const FOLIAGE_ROUGHNESS: float = 0.85

## @const COMMON_TEXTURE_PACKAGES (Array[String])
## O que: Lista de pacotes de textura frequentemente referenciados em cenários de vilas e campos.
## Porque: Permite busca rápida por correspondência de nome.
const COMMON_TEXTURE_PACKAGES: Array[String] = [
	"si_v_t",
	"speaking1f_t",
	"speaking_tree_t",
	"field_deco_t",
	"field_deco_artifact_t",
	"speakingfighter_t",
	"interior_b_ch_t",
	"statues_t",
	"sp_lighthouse",
	"entrance_t",
	"deco01",
	"gludio_port_t",
	"interior_b_t",
	"speaking_magic_t",
	"v_obj_t",
	"door_set_t",
	"fx_e_t",
	"manor_system_object_t",
	"speakingfighterbridge_t",
	"world_bridge_t",
	"world_bulletinboard_t",
	"gl_cv_t",
	"talking_village_t",
	"giran_village_t",
	"aden_village_t",
]

# ==============================================================================
# PROPRIEDADES DO NÓ
# ==============================================================================

var chunk_name: String = ""
var base_maps_path: String = "res://assets/maps"

var _multimesh_nodes: Array = []
var _material_recipes: Dictionary = { }
var _material_cache: Dictionary = { }
var _loaded_meshes: Array = []
var _parsed_instances: Array = []


func _init(p_chunk_name: String = "", p_base_path: String = "res://assets/maps") -> void:
	chunk_name = p_chunk_name
	base_maps_path = p_base_path


func _ready() -> void:
	if not chunk_name.is_empty():
		build_static_meshes()


func build_static_meshes() -> void:
	var resource_adapter = ChunkResourceAdapterClass.new(base_maps_path)
	_material_recipes = resource_adapter.load_material_recipes_dict(chunk_name)

	var actors_raw = resource_adapter.load_static_actors_array(chunk_name, false)
	if actors_raw.is_empty():
		return

	var inst_adapter = StaticMeshInstanceAdapterClass.new()
	_parsed_instances = inst_adapter.parse_actor_dictionaries(actors_raw)
	var groups = inst_adapter.group_by_mesh_path(_parsed_instances)

	for mesh_path in groups.keys():
		var instances = groups[mesh_path]
		var mesh = _load_mesh_resource(mesh_path)
		if mesh:
			if not _loaded_meshes.has(mesh):
				_loaded_meshes.append(mesh)
			_apply_materials_to_mesh(mesh)
			var mm_node = inst_adapter.create_multimesh_instance(mesh, instances)
			if mm_node:
				_multimesh_nodes.append(mm_node)
				add_child(mm_node)


func _load_mesh_resource(mesh_path: String) -> Mesh:
	return RuntimeAssetCacheClass.get_or_load_mesh(mesh_path)


func _apply_materials_to_mesh(mesh: Mesh) -> void:
	if not mesh:
		return
	for i in range(mesh.get_surface_count()):
		var surf_mat = mesh.surface_get_material(i)
		var mat_name = surf_mat.resource_name if surf_mat else ""
		if mat_name.is_empty():
			continue

		var resolved_mat = _get_or_create_material(mat_name)
		if resolved_mat:
			mesh.surface_set_material(i, resolved_mat)


func _get_or_create_material(mat_name: String) -> Material:
	var clean_name = mat_name.strip_edges().to_lower().replace(" ", "")
	if _material_cache.has(clean_name):
		return _material_cache[clean_name]

	# Gera variantes sem sufixos numéricos de instância (ex: msleaf1_1 -> msleaf1)
	var name_variants = [clean_name]
	for suf in ["_1", "_2", "_3", "_0", "_4"]:
		if clean_name.ends_with(suf):
			name_variants.append(clean_name.substr(0, clean_name.length() - suf.length()))

	# 1. Procura em _material_recipes por correspondência de chave
	var recipe: Dictionary = { }
	for v in name_variants:
		for k in _material_recipes.keys():
			var k_clean = k.to_lower().replace(" ", "")
			if k_clean == v or k_clean.ends_with("." + v):
				recipe = _material_recipes[k]
				break
		if not recipe.is_empty():
			break

	var diff_path = recipe.get("diffuse_texture", "")
	var tex: Texture2D = null

	if diff_path and not diff_path.is_empty():
		tex = _load_texture(diff_path)

	# 2. Fallback de textura direta em assets/textures/
	if not tex:
		for v in name_variants:
			tex = _find_texture_fallback(v)
			if tex:
				break

	if not tex:
		return null

	var std_mat = StandardMaterial3D.new()
	std_mat.albedo_texture = tex
	std_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	# Detecção inteligente de folhagens e vegetação (Árvores, Folhas, Arbustos)
	var is_foliage = false
	for v in name_variants:
		if (
			"leaf" in v or "leaves" in v or "branch" in v or "tree" in v or "grass" in v
			or "flower" in v or "fern" in v or "ivy" in v or "plant" in v or "flora" in v
		):
			is_foliage = true
			break

	var blend_mode = recipe.get("alpha_blend_mode", "Opaque")
	if is_foliage or blend_mode == "AlphaTest" or blend_mode == "AlphaBlend":
		std_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		std_mat.alpha_scissor_threshold = float(
			recipe.get("alpha_test_threshold", DEFAULT_ALPHA_SCISSOR_THRESHOLD)
		)
		std_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		std_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
		std_mat.roughness = FOLIAGE_ROUGHNESS

	if is_foliage or recipe.get("two_sided", false):
		std_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_material_cache[clean_name] = std_mat
	return std_mat


func _find_texture_fallback(clean_name: String) -> Texture2D:
	var candidates = [clean_name]
	if clean_name.begins_with("m_"):
		candidates.append(clean_name.substr(2))
	if clean_name.begins_with("s_"):
		candidates.append(clean_name.substr(2))
	if clean_name.begins_with("o_"):
		candidates.append(clean_name.substr(2))

	for pkg in COMMON_TEXTURE_PACKAGES:
		for c in candidates:
			var p = "res://assets/textures/%s/%s.png" % [pkg, c]
			var tex = _load_texture(p)
			if tex:
				return tex
	return null


func _load_texture(path: String) -> Texture2D:
	return RuntimeAssetCacheClass.get_or_load_texture(path, true)


func get_multimesh_count() -> int:
	return _multimesh_nodes.size()


func find_actor_under_ray(ray_origin: Vector3, ray_dir: Vector3) -> Dictionary:
	var closest_hit: Dictionary = { }
	var min_dist: float = 999999.0

	for inst in _parsed_instances:
		var xform = inst.get_transform()
		var mesh_path = inst.mesh_resource_path
		var mesh = RuntimeAssetCacheClass.get_or_load_mesh(mesh_path)

		var real_aabb: AABB
		if mesh:
			real_aabb = (xform * mesh.get_aabb()).abs()
		else:
			real_aabb = inst.get_world_aabb().abs()

		var expanded_aabb = real_aabb.grow(AABB_RAY_GROWTH_MARGIN)
		var hit_pos = expanded_aabb.intersects_ray(ray_origin, ray_dir)
		if hit_pos != null:
			var dist = ray_origin.distance_squared_to(hit_pos)
			if dist < min_dist:
				min_dist = dist
				var mesh_name = inst.mesh_name
				var mesh_pkg = ""
				if "/models/" in mesh_path:
					var parts = mesh_path.split("/models/")[1].split("/")
					if parts.size() > 0:
						mesh_pkg = parts[0]
				var surfaces_info = []

				if mesh:
					for i in range(mesh.get_surface_count()):
						var surf_mat = mesh.surface_get_material(i)
						var mat_name = surf_mat.resource_name if surf_mat else "surface_%d" % i
						var tex_status = _check_texture_status(mat_name)
						surfaces_info.append(
							{
								"index": i,
								"name": mat_name,
								"status": tex_status.status,
								"texture_path": tex_status.path,
							}
						)

				closest_hit = {
					"found": true,
					"actor_name": inst.actor_name,
					"mesh_name": mesh_name,
					"package_name": mesh_pkg,
					"position": inst.position,
					"transform": xform,
					"mesh": mesh,
					"aabb": real_aabb,
					"surfaces": surfaces_info,
					"distance": sqrt(dist),
				}

	return closest_hit


func _check_texture_status(mat_name: String) -> Dictionary:
	var clean_name = mat_name.strip_edges().to_lower().replace(" ", "")
	for k in _material_recipes.keys():
		var k_clean = k.to_lower().replace(" ", "")
		if k_clean == clean_name or k_clean.ends_with("." + clean_name):
			var r = _material_recipes[k]
			var diff = r.get("diffuse_texture", "")
			if diff:
				return { "status": "OK", "path": diff }

	var candidates = [clean_name]
	if clean_name.begins_with("m_"):
		candidates.append(clean_name.substr(2))
	if clean_name.begins_with("s_"):
		candidates.append(clean_name.substr(2))
	if clean_name.begins_with("o_"):
		candidates.append(clean_name.substr(2))

	for pkg in COMMON_TEXTURE_PACKAGES:
		for c in candidates:
			var p = "res://assets/textures/%s/%s.png" % [pkg, c]
			if (
				FileAccess.file_exists(p)
				or FileAccess.file_exists(ProjectSettings.globalize_path(p))
			):
				return { "status": "OK (Fallback)", "path": p }

	return { "status": "MISSING", "path": "" }
