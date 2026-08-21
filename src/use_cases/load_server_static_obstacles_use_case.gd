## @file load_server_static_obstacles_use_case.gd
## @path res://src/use_cases/load_server_static_obstacles_use_case.gd
##
## @description
## Caso de uso para carregar e converter atores estáticos de um chunk em um
## índice espacial analítico particionado (SpatialObstacleIndex) para o servidor autoritativo.
##
## @created 2026-08-21
## @updated 2026-08-21
##
## @author Leonardo S. Badaró
extends RefCounted

const SpatialObstacleIndexClass = preload("res://src/domain/spatial_obstacle_index.gd")
const SpatialStaticObstacleClass = preload("res://src/domain/spatial_static_obstacle.gd")
const ChunkResourceAdapterClass = preload("res://src/adapters/chunk_resource_adapter.gd")
const StaticMeshInstanceAdapterClass = preload("res://src/adapters/static_mesh_instance_adapter.gd")
const StaticMeshInstanceDataClass = preload("res://src/domain/static_mesh_instance_data.gd")


func execute(chunk_name: String, base_maps_path: String = "res://assets/maps") -> RefCounted:
	var index = SpatialObstacleIndexClass.new(chunk_name, 16.0)
	var adapter = ChunkResourceAdapterClass.new(base_maps_path)

	var rules = adapter.load_collision_rules_dict()
	var raw_actors = adapter.load_static_actors_array(chunk_name, true)
	if raw_actors.is_empty():
		raw_actors = adapter.load_static_actors_array(chunk_name, false)

	if raw_actors.is_empty():
		return index

	var inst_adapter = StaticMeshInstanceAdapterClass.new()
	var instances = inst_adapter.parse_actor_dictionaries(raw_actors)

	for inst in instances:
		if not (inst is StaticMeshInstanceDataClass):
			continue

		var classif = _classify_actor(inst, rules)
		var c_type = classif.get("type", "convex")

		if c_type == "pass_through":
			continue

		var actor_id = inst.actor_name if not inst.actor_name.is_empty() else str(inst.position)

		if c_type == "tree_trunk" or c_type == "tree_trunk_surface":
			var trunk_r = maxf(0.35, 0.45 * minf(absf(inst.scale.x), absf(inst.scale.z)))
			var trunk_h = maxf(4.0, 6.0 * absf(inst.scale.y))
			var min_y = inst.position.y - 1.0
			var max_y = inst.position.y + trunk_h

			var trunk_obs = SpatialStaticObstacleClass.create_cylinder(
				actor_id,
				Vector2(inst.position.x, inst.position.z),
				trunk_r,
				min_y,
				max_y
			)
			index.add_obstacle(trunk_obs)
		else:
			# Caixa AABB sólida para construções, muralhas, rochas e props
			var world_aabb = inst.get_world_aabb()
			# Se o AABB for padrão/vazio, dimensiona com base na escala
			if world_aabb.size.length_squared() < 0.1:
				var half_w = maxf(1.0, absf(inst.scale.x) * 2.0)
				var half_h = maxf(1.5, absf(inst.scale.y) * 3.0)
				var half_d = maxf(1.0, absf(inst.scale.z) * 2.0)
				world_aabb = AABB(
					inst.position - Vector3(half_w, 0.0, half_d),
					Vector3(half_w * 2.0, half_h * 2.0, half_d * 2.0)
				)

			var box_obs = SpatialStaticObstacleClass.create_box(
				actor_id,
				world_aabb.position,
				world_aabb.position + world_aabb.size
			)
			index.add_obstacle(box_obs)

	return index


func _classify_actor(inst: StaticMeshInstanceDataClass, rules: Dictionary) -> Dictionary:
	var m_name = inst.mesh_name.to_lower()
	var a_name = inst.actor_name.to_lower()
	var p_clean = m_name

	# 1. Custom Overrides
	var overrides = rules.get("custom_overrides", { })
	if overrides is Dictionary:
		for k in overrides.keys():
			var k_clean = k.to_lower()
			if k_clean in p_clean or k_clean in a_name:
				var ov = overrides[k]
				if ov is Dictionary:
					return ov

	# 2. Categorias
	var categories = rules.get("categories", { })
	if categories is Dictionary:
		var pass_list = categories.get("pass_through", [])
		for kw in pass_list:
			if kw in p_clean or kw in a_name:
				return { "type": "pass_through" }

		var tree_list = categories.get("tree_trunk_only", [])
		for kw in tree_list:
			if kw in p_clean or kw in a_name:
				return { "type": "tree_trunk", "surface_index": 0 }

		var concave_list = categories.get("concave_architecture", [])
		for kw in concave_list:
			if kw in p_clean or kw in a_name:
				return { "type": "concave" }

		var convex_list = categories.get("convex_props", [])
		for kw in convex_list:
			if kw in p_clean or kw in a_name:
				return { "type": "convex" }

	# 3. Fallbacks
	for kw in ["grass", "flower", "fern", "ivy", "bush", "shrub", "flora", "weed"]:
		if kw in p_clean or kw in a_name:
			return { "type": "pass_through" }

	for kw in ["tree", "branch", "trunk", "speaking_tree", "ti_tree", "si_tree"]:
		if kw in p_clean or kw in a_name:
			return { "type": "tree_trunk", "surface_index": 0 }

	return { "type": "convex" }
