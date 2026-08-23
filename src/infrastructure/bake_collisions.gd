## @file bake_collisions.gd
## @path res://src/infrastructure/bake_collisions.gd
##
## @description
## Script de linha de comando (CLI SceneTree) para compilação (bake) de colisões 3D estáticas.
## Lê regras centralizadas (static_mesh_collision_rules.json) e patches locais
## (chunk_static_actors_fix.json) e compila colisões pré-cozidas de alta performance
## para cada chunk em client/chunk_static_collision.tres.
##
## Uso:
##   godot --headless -s res://src/infrastructure/bake_collisions.gd
##   godot --headless -s res://src/infrastructure/bake_collisions.gd -- --chunk 17_25
##
## @created 2026-08-22
## @updated 2026-08-22
##
## @author Leonardo S. Badaró
extends SceneTree

const ChunkResourceAdapterClass = preload("res://src/adapters/chunk_resource_adapter.gd")
const StaticMeshInstanceAdapterClass = preload("res://src/adapters/static_mesh_instance_adapter.gd")
const StaticMeshInstanceDataClass = preload("res://src/domain/static_mesh_instance_data.gd")
const RuntimeAssetCacheClass = preload("res://src/infrastructure/runtime_asset_cache.gd")

const BASE_MAPS_PATH: String = "res://assets/maps"


func _init() -> void:
	print("=======================================================")
	print("[BAKE TOOL] Iniciando Pipeline de Bake de Colisao 3D...")
	print("=======================================================")

	var user_args = OS.get_cmdline_user_args()
	var main_args = OS.get_cmdline_args()
	var combined_args = user_args + main_args

	var target_chunk = ""
	for i in range(combined_args.size()):
		if (combined_args[i] == "--chunk" or combined_args[i] == "-c") and i + 1 < combined_args.size():
			target_chunk = combined_args[i + 1]
			break

	if not target_chunk.is_empty():
		bake_single_chunk(target_chunk)
	else:
		bake_all_chunks()

	quit(0)


func bake_single_chunk(chunk_name: String) -> void:
	var adapter = ChunkResourceAdapterClass.new(BASE_MAPS_PATH)
	var collision_rules = adapter.load_collision_rules_dict()
	print("[BAKE] Compilando colisoes apenas para o chunk '%s'..." % chunk_name)
	bake_chunk_collision(chunk_name, adapter, collision_rules)
	print("=======================================================")
	print("[BAKE TOOL] Bake do chunk '%s' concluido com sucesso!" % chunk_name)
	print("=======================================================")


func bake_all_chunks() -> void:
	var adapter = ChunkResourceAdapterClass.new(BASE_MAPS_PATH)
	var chunks = adapter.get_available_chunks()
	var collision_rules = adapter.load_collision_rules_dict()

	print("[BAKE] Encontrados %d chunks para processamento." % chunks.size())

	for chunk_name in chunks:
		bake_chunk_collision(chunk_name, adapter, collision_rules)

	print("=======================================================")
	print("[BAKE TOOL] Bake de todos os chunks concluido com sucesso!")
	print("=======================================================")


func bake_chunk_collision(chunk_name: String, adapter: RefCounted, collision_rules: Dictionary) -> void:
	var raw_actors = adapter.load_static_actors_array(chunk_name, false, true)
	if raw_actors.is_empty():
		print("[BAKE] Chunk '%s': Sem atores estaticos. Ignorando." % chunk_name)
		return

	var inst_adapter = StaticMeshInstanceAdapterClass.new()
	var parsed_instances = inst_adapter.parse_actor_dictionaries(raw_actors)
	var groups = inst_adapter.group_by_mesh_path(parsed_instances)
	var collision_shapes_data: Array[Dictionary] = []

	for mesh_path in groups.keys():
		var instances = groups[mesh_path]
		if instances.is_empty():
			continue

		var first_inst: StaticMeshInstanceDataClass = instances[0] if instances[0] is StaticMeshInstanceDataClass else null
		var classif = _classify_collision_type(mesh_path, first_inst, collision_rules)
		var c_type = classif.get("type", "convex")

		if c_type == "pass_through":
			continue

		var mesh = RuntimeAssetCacheClass.get_or_load_mesh(mesh_path)
		if not mesh:
			continue

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

		for inst in instances:
			if not (inst is StaticMeshInstanceDataClass):
				continue
			collision_shapes_data.append({
				"actor_name": inst.actor_name,
				"mesh_path": mesh_path,
				"collision_type": c_type,
				"shape": shape,
				"transform": inst.get_transform(),
			})

	# Salva a colecao de colisores compilados como um Resource (.tres)
	var target_dir = "%s/%s/client" % [BASE_MAPS_PATH, chunk_name]
	var target_file = "%s/chunk_static_collision.tres" % target_dir
	var write_path = ProjectSettings.globalize_path(target_file)

	var dir_path = write_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var shapes_dict: Dictionary = {}
	for item in collision_shapes_data:
		shapes_dict[item["actor_name"]] = {
			"mesh_path": item["mesh_path"],
			"collision_type": item["collision_type"],
			"shape": item["shape"],
			"transform": item["transform"],
		}

	var res_container = ConfigFile.new()
	for a_name in shapes_dict.keys():
		var data = shapes_dict[a_name]
		res_container.set_value(a_name, "mesh_path", data["mesh_path"])
		res_container.set_value(a_name, "collision_type", data["collision_type"])
		res_container.set_value(a_name, "transform", data["transform"])

	var err = res_container.save(write_path)
	if err == OK:
		print("[BAKE] Chunk '%s': %d colisores compilados salvos em '%s'." % [chunk_name, collision_shapes_data.size(), target_file])
	else:
		print("[BAKE] Erro ao salvar '%s' (codigo: %d)." % [target_file, err])


func _classify_collision_type(mesh_path: String, first_inst: StaticMeshInstanceDataClass, rules: Dictionary) -> Dictionary:
	var p_clean = mesh_path.to_lower()
	var m_name = first_inst.mesh_name.to_lower() if first_inst else ""
	var a_name = first_inst.actor_name.to_lower() if first_inst else ""

	# Nivel 1: Custom Overrides no JSON
	var overrides = rules.get("custom_overrides", { })
	if overrides is Dictionary:
		for k in overrides.keys():
			var k_clean = k.to_lower()
			if k_clean in p_clean or k_clean == m_name or k_clean in a_name:
				var ov = overrides[k]
				if ov is Dictionary:
					return ov

	# Nivel 2: Categorias no JSON
	var categories = rules.get("categories", { })
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

	# Nivel 3: Fallbacks Heuristicos
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
