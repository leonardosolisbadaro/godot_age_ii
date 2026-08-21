## @file static_mesh_chunk_node.gd
## @path res://src/infrastructure/static_mesh_chunk_node.gd
##
## @description
## Nó 3D da camada de infraestrutura que encapsula e exibe os atores estáticos
## (MultiMeshInstance3D) e colisores reais (Jolt Physics) de um chunk no mundo.
##
## @created 2026-08-20
## @updated 2026-08-21
##
## @author Leonardo S. Badaró
extends Node3D

const StaticMeshInstanceAdapterClass = preload("res://src/adapters/static_mesh_instance_adapter.gd")
const StaticMeshInstanceDataClass = preload("res://src/domain/static_mesh_instance_data.gd")
const ChunkResourceAdapterClass = preload("res://src/adapters/chunk_resource_adapter.gd")
const RuntimeAssetCacheClass = preload("res://src/infrastructure/runtime_asset_cache.gd")

# ==============================================================================
# CONSTANTES SEMÂNTICAS
# ==============================================================================

## @const COMMON_TEXTURE_PACKAGES (Array[String])
## O que: Lista de pacotes de textura comuns do Lineage II para busca de fallback.
## Porque: Facilita a resolução de texturas sem caminho explícito nos metadados.
const COMMON_TEXTURE_PACKAGES: Array[String] = [
	"TI_T",
	"Castle_T",
	"Town_T",
	"Village_T",
	"Dungeon_T",
	"Deco_T",
	"Plants_T",
	"Tree_T",
	"Water_T",
	"Effect_T",
	"T_17_25",
	"T_16_24",
	"T_16_25",
	"T_17_24",
]

## @const DEFAULT_ALPHA_SCISSOR_THRESHOLD (float)
## O que: Limiar de corte alfa padrão para folhagens e tecidos (0.5).
## Porque: Separação nítida de transparência binária sem artefatos de borda.
const DEFAULT_ALPHA_SCISSOR_THRESHOLD: float = 0.5

## @const FOLIAGE_ROUGHNESS (float)
## O que: Rugosidade padrão de materiais de folhagens e vegetação (0.85).
## Porque: Dispersão natural de luz solar na copa de árvores.
const FOLIAGE_ROUGHNESS: float = 0.85

## @const AABB_RAY_GROWTH_MARGIN (float)
## O que: Margem de expansão do AABB para picking de raios do mouse (0.2m).
## Porque: Garante facilidade de clique no inspetor de materiais.
const AABB_RAY_GROWTH_MARGIN: float = 0.2

# ==============================================================================
# PROPRIEDADES DO NÓ
# ==============================================================================

var chunk_name: String = ""
var base_maps_path: String = "res://assets/maps"

var _multimesh_nodes: Array[MultiMeshInstance3D] = []
var _material_recipes: Dictionary = { }
var _material_cache: Dictionary = { }
var _loaded_meshes: Array[Mesh] = []
var _parsed_instances: Array = []


func _init(p_chunk_name: String = "", p_base_path: String = "res://assets/maps") -> void:
	chunk_name = p_chunk_name
	base_maps_path = p_base_path


func _ready() -> void:
	if not chunk_name.is_empty():
		build_static_meshes()


var _collision_rules: Dictionary = { }


func build_static_meshes() -> void:
	var resource_adapter = ChunkResourceAdapterClass.new(base_maps_path)
	_material_recipes = resource_adapter.load_material_recipes_dict(chunk_name)
	_collision_rules = resource_adapter.load_collision_rules_dict()

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
				# Otimização de Sombras e Culling em Folhagens/Vegetação
				if _is_foliage_or_small_vegetation(mesh_path, instances):
					mm_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					mm_node.visibility_range_end = 400.0
					mm_node.visibility_range_end_margin = 50.0
					mm_node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

				_multimesh_nodes.append(mm_node)
				add_child(mm_node)

	_setup_static_mesh_collisions(groups)


func _classify_collision_type(mesh_path: String, first_inst: StaticMeshInstanceDataClass) -> Dictionary:
	var p_clean = mesh_path.to_lower()
	var m_name = first_inst.mesh_name.to_lower() if first_inst else ""
	var a_name = first_inst.actor_name.to_lower() if first_inst else ""

	# Nível 1: Custom Overrides no JSON
	var overrides = _collision_rules.get("custom_overrides", { })
	if overrides is Dictionary:
		for k in overrides.keys():
			var k_clean = k.to_lower()
			if k_clean in p_clean or k_clean == m_name or k_clean in a_name:
				var ov = overrides[k]
				if ov is Dictionary:
					return ov

	# Nível 2: Categorias no JSON
	var categories = _collision_rules.get("categories", { })
	if categories is Dictionary:
		var pass_list = categories.get("pass_through", [])
		for kw in pass_list:
			if kw in p_clean or kw == m_name:
				return { "type": "pass_through" }

		var tree_list = categories.get("tree_trunk_only", [])
		for kw in tree_list:
			if kw in p_clean or kw in m_name:
				return { "type": "tree_trunk", "surface_index": 0 }

		var concave_list = categories.get("concave_architecture", [])
		for kw in concave_list:
			if kw in p_clean or kw in m_name:
				return { "type": "concave" }

		var convex_list = categories.get("convex_props", [])
		for kw in convex_list:
			if kw in p_clean or kw in m_name:
				return { "type": "convex" }

	# Nível 3: Fallbacks Heurísticos Inteligentes
	for kw in ["grass", "flower", "fern", "ivy", "bush", "shrub", "flora", "weed", "deco_plant"]:
		if kw in p_clean or kw in m_name:
			return { "type": "pass_through" }

	for kw in ["tree", "branch", "trunk", "speaking_tree", "ti_tree", "si_tree"]:
		if kw in p_clean or kw in m_name:
			return { "type": "tree_trunk", "surface_index": 0 }

	if first_inst:
		var sz = first_inst.base_aabb.size * first_inst.scale
		if sz.x > 3.0 or sz.z > 3.0 or sz.y > 2.5:
			return { "type": "concave" }

	return { "type": "convex" }


func _is_foliage_or_small_vegetation(mesh_path: String, instances: Array) -> bool:
	var first_inst: StaticMeshInstanceDataClass = instances[0] if not instances.is_empty() and instances[0] is StaticMeshInstanceDataClass else null
	var classif = _classify_collision_type(mesh_path, first_inst)
	return classif.get("type", "") == "pass_through"


func _setup_static_mesh_collisions(groups: Dictionary) -> void:
	if groups.is_empty():
		return

	var body = StaticBody3D.new()
	body.name = "StaticMeshesCollisionBody"

	for mesh_path in groups.keys():
		var instances = groups[mesh_path]
		if instances.is_empty():
			continue

		var first_inst: StaticMeshInstanceDataClass = instances[0] if instances[0] is StaticMeshInstanceDataClass else null
		var classif = _classify_collision_type(mesh_path, first_inst)
		var c_type = classif.get("type", "convex")

		# 1. Pass-Through (Grama, Flores, etc.)
		if c_type == "pass_through":
			continue

		# 2. Carrega Malha 3D
		var mesh = _load_mesh_resource(mesh_path)
		if not mesh:
			continue

		# 3. Determina o Shape de Colisão
		var shape: Shape3D = null
		if c_type == "tree_trunk" or c_type == "tree_trunk_surface":
			var surf_idx = int(classif.get("surface_index", 0))
			shape = RuntimeAssetCacheClass.get_or_create_trunk_convex_shape(mesh_path, mesh, surf_idx)
		elif c_type == "concave":
			shape = RuntimeAssetCacheClass.get_or_create_trimesh_shape(mesh_path, mesh)
		else:
			shape = RuntimeAssetCacheClass.get_or_create_convex_shape(mesh_path, mesh)

		if not shape:
			continue

		# 4. Instancia CollisionShape3D com o Transform3D exato de cada ator
		for inst in instances:
			if not (inst is StaticMeshInstanceDataClass):
				continue

			var shape_node = CollisionShape3D.new()
			shape_node.shape = shape
			shape_node.transform = inst.get_transform()
			body.add_child(shape_node)

	if body.get_child_count() > 0:
		add_child(body)


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

	# Detecção inteligente de folhagens, tecidos, bandeiras e adereços planos (Two-Sided)
	var is_two_sided = false
	var is_foliage = false
	for v in name_variants:
		if (
			"leaf" in v or "leaves" in v or "branch" in v or "tree" in v or "grass" in v
			or "flower" in v or "fern" in v or "ivy" in v or "plant" in v or "flora" in v
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
		# Fallback neutro com cull_mode desabilitado para evitar faces traseiras invisíveis
		var fallback_mat = StandardMaterial3D.new()
		fallback_mat.albedo_color = Color(0.75, 0.72, 0.68, 1.0)
		fallback_mat.roughness = 0.8
		fallback_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_material_cache[clean_name] = fallback_mat
		return fallback_mat

	var std_mat = StandardMaterial3D.new()
	std_mat.albedo_texture = tex
	std_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	var blend_mode = recipe.get("alpha_blend_mode", "Opaque")
	if is_foliage or blend_mode == "AlphaTest" or blend_mode == "AlphaBlend":
		std_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		std_mat.alpha_scissor_threshold = float(
			recipe.get("alpha_test_threshold", DEFAULT_ALPHA_SCISSOR_THRESHOLD)
		)
		std_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		std_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
		std_mat.roughness = FOLIAGE_ROUGHNESS

	if is_two_sided or recipe.get("two_sided", false):
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
