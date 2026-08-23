## @file world_chunk_manager.gd
## @path res://src/infrastructure/world_chunk_manager.gd
##
## @description
## Gerenciador central de infraestrutura no cliente responsável pelo ciclo de vida
## e streaming contínuo de chunks visuais de terreno e atores estáticos no mundo.
##
## @created 2026-08-19
## @updated 2026-08-21
##
## @author Leonardo S. Badaró
extends Node3D

const ChunkResourceAdapterClass = preload("res://src/adapters/chunk_resource_adapter.gd")
const LoadChunkMetadataUseCaseClass = preload("res://src/use_cases/load_chunk_metadata_use_case.gd")
const StreamWorldChunksUseCaseClass = preload("res://src/use_cases/stream_world_chunks_use_case.gd")
const L2TerrainChunkNodeClass = preload("res://src/infrastructure/l2_terrain_chunk_node.gd")
const StaticMeshChunkNodeClass = preload("res://src/infrastructure/static_mesh_chunk_node.gd")
const HeightfieldSamplerClass = preload("res://src/domain/heightfield_sampler.gd")

# ==============================================================================
# CONSTANTES SEMÂNTICAS DE GERENCIAMENTO DE MUNDO
# ==============================================================================

## @const DEFAULT_VIEW_RADIUS_METERS (float)
## O que: Raio de visão de streaming padrão em metros (1200.0m).
## Porque: Distância balanceada de carregamento para visualização e performance.
const DEFAULT_VIEW_RADIUS_METERS: float = 1200.0

## @const INFINITE_RAY_DISTANCE (float)
## O que: Distância infinita sentinela para testes de interseção de raios (999999.0m).
## Porque: Inicializador de busca de menor distância.
const INFINITE_RAY_DISTANCE: float = 999999.0

# ==============================================================================
# PROPRIEDADES DO GERENCIADOR
# ==============================================================================

var base_maps_path: String = "res://assets/maps"
var view_radius_meters: float = DEFAULT_VIEW_RADIUS_METERS

var _known_chunks: Dictionary = { } # { "16_24": TerrainChunkData, ... }
var _active_terrain_nodes: Dictionary = { } # { "16_24": L2TerrainChunkNode, ... }
var _active_mesh_nodes: Dictionary = { } # { "16_24": StaticMeshChunkNode, ... }
var _samplers: Dictionary = { } # { "16_24": HeightfieldSampler, ... }
var _loading_chunks: Dictionary = { } # { "16_24": true, ... }
var _pending_actor_fixes: Dictionary = { } # { chunk_name -> { actor_name -> { "position": Vector3, "rotation_degrees": Vector3, "scale": Vector3 } } }

var _resource_adapter: RefCounted
var _meta_use_case: RefCounted
var _stream_use_case: RefCounted


func _init(p_base_path: String = "res://assets/maps", p_radius: float = DEFAULT_VIEW_RADIUS_METERS) -> void:
	base_maps_path = p_base_path
	view_radius_meters = p_radius
	_resource_adapter = ChunkResourceAdapterClass.new(base_maps_path)
	_meta_use_case = LoadChunkMetadataUseCaseClass.new()
	_stream_use_case = StreamWorldChunksUseCaseClass.new()


func register_chunk(chunk_name: String) -> bool:
	if _known_chunks.has(chunk_name):
		return true

	var chunk_data = _meta_use_case.execute(chunk_name, _resource_adapter, true)
	if chunk_data:
		_known_chunks[chunk_name] = chunk_data
		return true
	return false


func register_available_chunks() -> Array[String]:
	var registered: Array[String] = []
	var available = _resource_adapter.get_available_chunks()
	for c_name in available:
		if register_chunk(c_name):
			registered.append(c_name)
	return registered


func update_streaming(avatar_pos: Vector3, async: bool = false) -> void:
	var loaded_names = _active_terrain_nodes.keys()
	var stream_res = _stream_use_case.execute(
		avatar_pos,
		view_radius_meters,
		_known_chunks,
		loaded_names,
	)

	# 1. Carrega novos chunks no raio de visão
	for c_name in stream_res.get("to_load", []):
		load_chunk(c_name, async)

	# 2. Descarrega chunks fora do raio de visão
	for c_name in stream_res.get("to_unload", []):
		unload_chunk(c_name)


func load_chunk(chunk_name: String, async: bool = false) -> void:
	if _active_terrain_nodes.has(chunk_name) or _loading_chunks.has(chunk_name):
		return

	if async:
		_loading_chunks[chunk_name] = true
		WorkerThreadPool.add_task(_thread_load_chunk.bind(chunk_name))
		return

	# Carregamento síncrono imediato
	_build_and_attach_chunk_nodes(chunk_name)


func _thread_load_chunk(chunk_name: String) -> void:
	var terrain_node = L2TerrainChunkNodeClass.new(chunk_name, base_maps_path)
	terrain_node.build_chunk_node()

	var mesh_node = StaticMeshChunkNodeClass.new(chunk_name, base_maps_path)
	mesh_node.build_static_meshes()

	call_deferred("_on_chunk_background_loaded", chunk_name, terrain_node, mesh_node)


func _on_chunk_background_loaded(chunk_name: String, terrain_node: Node3D, mesh_node: Node3D) -> void:
	_loading_chunks.erase(chunk_name)

	if _active_terrain_nodes.has(chunk_name):
		if terrain_node:
			terrain_node.queue_free()
		if mesh_node:
			mesh_node.queue_free()
		return

	# Anexa terreno na cena
	if terrain_node:
		terrain_node.name = "Terrain_%s" % chunk_name
		var chunk_data = _known_chunks.get(chunk_name)
		if chunk_data:
			terrain_node.position = chunk_data.world_origin
		add_child(terrain_node)
		_active_terrain_nodes[chunk_name] = terrain_node

	# Anexa atores estáticos na cena
	if mesh_node:
		mesh_node.name = "StaticMeshes_%s" % chunk_name
		add_child(mesh_node)
		_active_mesh_nodes[chunk_name] = mesh_node


func _build_and_attach_chunk_nodes(chunk_name: String) -> void:
	# Instancia Terreno Visual
	var terrain_node = L2TerrainChunkNodeClass.new(chunk_name, base_maps_path)
	terrain_node.name = "Terrain_%s" % chunk_name
	terrain_node.build_chunk_node()
	var chunk_data = _known_chunks.get(chunk_name)
	if chunk_data:
		terrain_node.position = chunk_data.world_origin
	add_child(terrain_node)
	_active_terrain_nodes[chunk_name] = terrain_node

	# Instancia Atores Estáticos (MultiMesh)
	var mesh_node = StaticMeshChunkNodeClass.new(chunk_name, base_maps_path)
	mesh_node.name = "StaticMeshes_%s" % chunk_name
	mesh_node.build_static_meshes()
	add_child(mesh_node)
	_active_mesh_nodes[chunk_name] = mesh_node


func unload_chunk(chunk_name: String) -> void:
	_loading_chunks.erase(chunk_name)

	if _active_terrain_nodes.has(chunk_name):
		var t_node = _active_terrain_nodes[chunk_name]
		_active_terrain_nodes.erase(chunk_name)
		t_node.queue_free()

	if _active_mesh_nodes.has(chunk_name):
		var m_node = _active_mesh_nodes[chunk_name]
		_active_mesh_nodes.erase(chunk_name)
		m_node.queue_free()


func get_active_terrain_node(chunk_name: String) -> Node3D:
	return _active_terrain_nodes.get(chunk_name, null)


func get_chunk_water_volumes(chunk_name: String) -> Dictionary:
	var t_node = get_active_terrain_node(chunk_name)
	if t_node and t_node.has_method("get_water_volumes_data"):
		return t_node.get_water_volumes_data()
	return _resource_adapter.load_water_volumes_dict(chunk_name)


func save_water_volumes_fix_for_chunk(chunk_name: String) -> bool:
	var data = get_chunk_water_volumes(chunk_name)
	if data.is_empty():
		return false
	return _resource_adapter.save_water_volumes_fix(chunk_name, data)


func update_water_volume_runtime(chunk_name: String, volume_name: String, data: Dictionary) -> bool:
	var t_node = get_active_terrain_node(chunk_name)
	if t_node and t_node.has_method("update_water_volume_runtime"):
		return t_node.update_water_volume_runtime(volume_name, data)
	return false


func save_single_water_volume_fix(chunk_name: String, volume_name: String, data: Dictionary) -> bool:
	var raw_data: Dictionary = { }
	var t_node = get_active_terrain_node(chunk_name)
	if t_node and t_node.has_method("get_raw_water_volume_data"):
		raw_data = t_node.get_raw_water_volume_data(volume_name)

	var raw_y = float(raw_data.get("surface_y_m", raw_data.get("water_plane_height_m", 0.0)))
	var raw_center = raw_data.get("center_m", [0.0, 0.0])
	var raw_cx = float(raw_center[0]) if (raw_center is Array and raw_center.size() >= 2) else 0.0
	var raw_cz = float(raw_center[1]) if (raw_center is Array and raw_center.size() >= 2) else 0.0

	var raw_size = raw_data.get("size_m", [2621.44, 2621.44])
	var raw_sx = float(raw_size[0]) if (raw_size is Array and raw_size.size() >= 2) else 2621.44
	var raw_sz = float(raw_size[1]) if (raw_size is Array and raw_size.size() >= 2) else 2621.44

	var raw_ext = float(raw_data.get("ocean_extension", 0.0))
	var raw_enabled = bool(raw_data.get("enabled", true))

	var new_y = float(data.get("surface_y_m", data.get("water_plane_height_m", 0.0)))
	var new_center = data.get("center_m", [0.0, 0.0])
	var new_cx = float(new_center[0]) if (new_center is Array and new_center.size() >= 2) else 0.0
	var new_cz = float(new_center[1]) if (new_center is Array and new_center.size() >= 2) else 0.0

	var new_size = data.get("size_m", [2621.44, 2621.44])
	var new_sx = float(new_size[0]) if (new_size is Array and new_size.size() >= 2) else 2621.44
	var new_sz = float(new_size[1]) if (new_size is Array and new_size.size() >= 2) else 2621.44

	var new_ext = float(data.get("ocean_extension", 0.0))
	var new_enabled = bool(data.get("enabled", true))

	var is_modified = false
	if not is_equal_approx(raw_y, new_y):
		is_modified = true
	if not is_equal_approx(raw_cx, new_cx) or not is_equal_approx(raw_cz, new_cz):
		is_modified = true
	if not is_equal_approx(raw_sx, new_sx) or not is_equal_approx(raw_sz, new_sz):
		is_modified = true
	if not is_equal_approx(raw_ext, new_ext):
		is_modified = true
	if raw_enabled != new_enabled:
		is_modified = true

	var fix_data = _resource_adapter.load_water_volumes_fix_dict(chunk_name)
	var fix_volumes = fix_data.get("water_volumes", { })
	if not (fix_volumes is Dictionary):
		fix_volumes = { }

	if not is_modified:
		fix_volumes.erase(volume_name)
	else:
		fix_volumes[volume_name] = data

	var save_payload = {
		"water_volumes": fix_volumes,
	}
	return _resource_adapter.save_water_volumes_fix(chunk_name, save_payload)


func reset_water_volume(chunk_name: String, volume_name: String) -> Dictionary:
	var fix_data = _resource_adapter.load_water_volumes_fix_dict(chunk_name)
	var fix_volumes = fix_data.get("water_volumes", { })
	if fix_volumes is Dictionary and fix_volumes.has(volume_name):
		fix_volumes.erase(volume_name)
		_resource_adapter.save_water_volumes_fix(chunk_name, { "water_volumes": fix_volumes })

	var raw_data: Dictionary = { }
	var t_node = get_active_terrain_node(chunk_name)
	if t_node and t_node.has_method("get_raw_water_volume_data"):
		raw_data = t_node.get_raw_water_volume_data(volume_name)
		if not raw_data.is_empty():
			t_node.update_water_volume_runtime(volume_name, raw_data)

	return raw_data



func set_wireframe_enabled(enabled: bool) -> void:
	for t_node in _active_terrain_nodes.values():
		if t_node and t_node.has_method("set_wireframe_enabled"):
			t_node.set_wireframe_enabled(enabled)


func inspect_object_at_ray(ray_origin: Vector3, ray_dir: Vector3) -> Dictionary:
	var closest_hit: Dictionary = { }
	var min_dist: float = INFINITE_RAY_DISTANCE

	for m_node in _active_mesh_nodes.values():
		if m_node and m_node.has_method("find_actor_under_ray"):
			var hit = m_node.find_actor_under_ray(ray_origin, ray_dir)
			if hit.get("found", false):
				var d = float(hit.get("distance", INFINITE_RAY_DISTANCE))
				if d < min_dist:
					min_dist = d
					closest_hit = hit

	return closest_hit


func sample_world_altitude(world_x: float, world_z: float) -> Dictionary:
	for c_name in _known_chunks.keys():
		var chunk = _known_chunks[c_name]
		if chunk and chunk.has_method("contains_world_point") and chunk.contains_world_point(world_x, world_z):
			if not _samplers.has(c_name):
				var hf_bytes = _resource_adapter.load_heightfield_bytes(c_name)
				if not hf_bytes.is_empty():
					var sampler = HeightfieldSamplerClass.from_chunk_data_and_bytes(chunk, hf_bytes)
					if sampler:
						_samplers[c_name] = sampler
			if _samplers.has(c_name):
				var sampler = _samplers[c_name]
				var alt = sampler.get_height_at(world_x, world_z)
				return {
					"found": true,
					"chunk_name": c_name,
					"altitude": alt,
				}
	return { "found": false, "altitude": 0.0 }


func get_active_chunk_count() -> int:
	return _active_terrain_nodes.size()


func get_static_actors_in_radius(center_pos: Vector3, radius: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for m_node in _active_mesh_nodes.values():
		if m_node and m_node.has_method("get_actors_in_radius"):
			var chunk_actors = m_node.get_actors_in_radius(center_pos, radius)
			result.append_array(chunk_actors)

	result.sort_custom(func(a, b): return a.get("distance", 0.0) < b.get("distance", 0.0))
	return result


func update_static_actor_transform(
	actor_name: String,
	new_pos: Vector3,
	new_rot_deg: Vector3,
	new_scale: Vector3,
	chunk_name: String = ""
) -> Dictionary:
	for m_node in _active_mesh_nodes.values():
		if not chunk_name.is_empty() and m_node.chunk_name != chunk_name:
			continue
		if m_node and m_node.has_method("update_actor_transform"):
			var res = m_node.update_actor_transform(actor_name, new_pos, new_rot_deg, new_scale)
			if res.get("found", false):
				var target_chunk = m_node.chunk_name
				res["chunk_name"] = target_chunk
				if not _pending_actor_fixes.has(target_chunk):
					_pending_actor_fixes[target_chunk] = { }
				_pending_actor_fixes[target_chunk][actor_name] = {
					"position": new_pos,
					"rotation_degrees": new_rot_deg,
					"scale": new_scale,
				}
				return res
	return { "found": false }


func get_raw_actor_data(actor_name: String, chunk_name: String = "") -> Dictionary:
	for m_node in _active_mesh_nodes.values():
		if not chunk_name.is_empty() and m_node.chunk_name != chunk_name:
			continue
		if m_node and m_node.has_method("get_raw_actor_data"):
			var raw = m_node.get_raw_actor_data(actor_name)
			if not raw.is_empty():
				return raw
	return { }


func update_actor_collision_type(actor_name: String, new_type: String, chunk_name: String = "") -> bool:
	for m_node in _active_mesh_nodes.values():
		if not chunk_name.is_empty() and m_node.chunk_name != chunk_name:
			continue
		if m_node and m_node.has_method("update_actor_collision_type"):
			var res = m_node.update_actor_collision_type(actor_name, new_type)
			if res:
				return true
	return false


func save_collision_rule_override(package_name: String, mesh_name: String, collision_type: String) -> bool:
	if _resource_adapter and _resource_adapter.has_method("save_collision_override"):
		return _resource_adapter.save_collision_override(package_name, mesh_name, collision_type)
	return false


func get_pending_fixes_summary() -> Dictionary:
	var total_actors = 0
	var chunks: Array[String] = []
	var dirty_set: Dictionary = { }
	for c_name in _pending_actor_fixes.keys():
		var acts = _pending_actor_fixes[c_name]
		if acts is Dictionary and not acts.is_empty():
			total_actors += acts.size()
			chunks.append(c_name)
			for a_name in acts.keys():
				dirty_set[a_name] = true
	return {
		"total_actors": total_actors,
		"chunks_count": chunks.size(),
		"chunks": chunks,
		"dirty_set": dirty_set,
	}


func is_actor_dirty(actor_name: String, chunk_name: String = "") -> bool:
	if not chunk_name.is_empty():
		return _pending_actor_fixes.has(chunk_name) and _pending_actor_fixes[chunk_name].has(actor_name)
	for c_name in _pending_actor_fixes.keys():
		if _pending_actor_fixes[c_name].has(actor_name):
			return true
	return false


func remove_from_pending_fixes(actor_name: String, chunk_name: String = "") -> void:
	if not chunk_name.is_empty():
		if _pending_actor_fixes.has(chunk_name) and _pending_actor_fixes[chunk_name].has(actor_name):
			_pending_actor_fixes[chunk_name].erase(actor_name)
			if _pending_actor_fixes[chunk_name].is_empty():
				_pending_actor_fixes.erase(chunk_name)
	else:
		for c_name in _pending_actor_fixes.keys():
			if _pending_actor_fixes[c_name].has(actor_name):
				_pending_actor_fixes[c_name].erase(actor_name)
				if _pending_actor_fixes[c_name].is_empty():
					_pending_actor_fixes.erase(c_name)


func save_actor_fix(
	actor_name: String,
	new_pos: Vector3,
	new_rot_deg: Vector3,
	new_scale: Vector3,
	chunk_name: String = ""
) -> bool:
	var target_chunk = ""
	var raw_actor: Dictionary = { }
	for m_node in _active_mesh_nodes.values():
		if not chunk_name.is_empty() and m_node.chunk_name != chunk_name:
			continue
		if m_node and m_node.has_method("get_raw_actor_data"):
			var raw = m_node.get_raw_actor_data(actor_name)
			if not raw.is_empty():
				target_chunk = m_node.chunk_name
				raw_actor = raw
				break

	if target_chunk.is_empty():
		return false

	var fix_data = _resource_adapter.load_static_actors_fix_dict(target_chunk)
	if not fix_data.has("actors") or not (fix_data["actors"] is Dictionary):
		if fix_data.has("actors") and fix_data["actors"] is Array:
			var actors_dict = { }
			for a in fix_data["actors"]:
				if a is Dictionary and a.has("actor_name"):
					actors_dict[a["actor_name"]] = a
			fix_data["actors"] = actors_dict
		else:
			fix_data["actors"] = { }

	# Calcula estritamente o delta dos atributos alterados em relação ao raw
	var transform_diff: Dictionary = { }
	var raw_pos: Vector3 = raw_actor.get("position", Vector3.ZERO)
	var raw_rot: Vector3 = raw_actor.get("rotation_degrees", Vector3.ZERO)
	var raw_scl: Vector3 = raw_actor.get("scale", Vector3.ONE)

	var raw_pos_arr = raw_actor.get("raw_position", [])
	var raw_rot_arr = raw_actor.get("raw_rotation_degrees", [])
	var raw_scl_arr = raw_actor.get("raw_scale", [])

	var raw_pos_x = float(raw_pos_arr[0]) if (raw_pos_arr is Array and raw_pos_arr.size() >= 3) else raw_pos.x
	var raw_pos_y = float(raw_pos_arr[1]) if (raw_pos_arr is Array and raw_pos_arr.size() >= 3) else raw_pos.y
	var raw_pos_z = float(raw_pos_arr[2]) if (raw_pos_arr is Array and raw_pos_arr.size() >= 3) else raw_pos.z

	var raw_rot_x = float(raw_rot_arr[0]) if (raw_rot_arr is Array and raw_rot_arr.size() >= 3) else raw_rot.x
	var raw_rot_y = float(raw_rot_arr[1]) if (raw_rot_arr is Array and raw_rot_arr.size() >= 3) else raw_rot.y
	var raw_rot_z = float(raw_rot_arr[2]) if (raw_rot_arr is Array and raw_rot_arr.size() >= 3) else raw_rot.z

	var raw_scl_x = float(raw_scl_arr[0]) if (raw_scl_arr is Array and raw_scl_arr.size() >= 3) else raw_scl.x
	var raw_scl_y = float(raw_scl_arr[1]) if (raw_scl_arr is Array and raw_scl_arr.size() >= 3) else raw_scl.y
	var raw_scl_z = float(raw_scl_arr[2]) if (raw_scl_arr is Array and raw_scl_arr.size() >= 3) else raw_scl.z

	if not is_equal_approx(raw_pos_x, new_pos.x) or not is_equal_approx(raw_pos_y, new_pos.y) or not is_equal_approx(raw_pos_z, new_pos.z):
		var fx = raw_pos_x if is_equal_approx(raw_pos_x, new_pos.x) else round(new_pos.x * 1000.0) / 1000.0
		var fy = raw_pos_y if is_equal_approx(raw_pos_y, new_pos.y) else round(new_pos.y * 1000.0) / 1000.0
		var fz = raw_pos_z if is_equal_approx(raw_pos_z, new_pos.z) else round(new_pos.z * 1000.0) / 1000.0
		transform_diff["location_meters"] = [fx, fy, fz]

	if not is_equal_approx(raw_rot_x, new_rot_deg.x) or not is_equal_approx(raw_rot_y, new_rot_deg.y) or not is_equal_approx(raw_rot_z, new_rot_deg.z):
		var rx = raw_rot_x if is_equal_approx(raw_rot_x, new_rot_deg.x) else round(new_rot_deg.x * 1000.0) / 1000.0
		var ry = raw_rot_y if is_equal_approx(raw_rot_y, new_rot_deg.y) else round(new_rot_deg.y * 1000.0) / 1000.0
		var rz = raw_rot_z if is_equal_approx(raw_rot_z, new_rot_deg.z) else round(new_rot_deg.z * 1000.0) / 1000.0
		transform_diff["rotation_degrees"] = [rx, ry, rz]

	if not is_equal_approx(raw_scl_x, new_scale.x) or not is_equal_approx(raw_scl_y, new_scale.y) or not is_equal_approx(raw_scl_z, new_scale.z):
		var sx = raw_scl_x if is_equal_approx(raw_scl_x, new_scale.x) else round(new_scale.x * 1000.0) / 1000.0
		var sy = raw_scl_y if is_equal_approx(raw_scl_y, new_scale.y) else round(new_scale.y * 1000.0) / 1000.0
		var sz = raw_scl_z if is_equal_approx(raw_scl_z, new_scale.z) else round(new_scale.z * 1000.0) / 1000.0
		transform_diff["scale"] = [sx, sy, sz]

	if transform_diff.is_empty():
		fix_data["actors"].erase(actor_name)
	else:
		fix_data["actors"][actor_name] = {
			"transform": transform_diff,
		}

	var success = _resource_adapter.save_static_actors_fix(target_chunk, fix_data)
	if success:
		remove_from_pending_fixes(actor_name, target_chunk)
	return success


func save_all_pending_actor_fixes() -> Dictionary:
	var saved_count = 0
	var saved_chunks: Array[String] = []
	var chunks_to_process = _pending_actor_fixes.keys().duplicate()

	for c_name in chunks_to_process:
		var actors_dict = _pending_actor_fixes.get(c_name, { }).duplicate()
		if not (actors_dict is Dictionary) or actors_dict.is_empty():
			continue

		for a_name in actors_dict.keys():
			var t_data = actors_dict[a_name]
			var pos = t_data.get("position", Vector3.ZERO)
			var rot = t_data.get("rotation_degrees", Vector3.ZERO)
			var sc = t_data.get("scale", Vector3.ONE)
			var ok = save_actor_fix(a_name, pos, rot, sc, c_name)
			if ok:
				saved_count += 1

		if not saved_chunks.has(c_name):
			saved_chunks.append(c_name)

	_pending_actor_fixes.clear()
	return {
		"success": true,
		"saved_actors_count": saved_count,
		"saved_chunks": saved_chunks,
	}


func discard_all_pending_actor_fixes() -> int:
	var reverted_count = 0
	var chunks_to_process = _pending_actor_fixes.keys().duplicate()

	for c_name in chunks_to_process:
		var actors_dict = _pending_actor_fixes.get(c_name, { }).duplicate()
		if not (actors_dict is Dictionary):
			continue
		for a_name in actors_dict.keys():
			var raw = get_raw_actor_data(a_name, c_name)
			if not raw.is_empty():
				var pos = raw.get("position", Vector3.ZERO)
				var rot = raw.get("rotation_degrees", Vector3.ZERO)
				var sc = raw.get("scale", Vector3.ONE)
				for m_node in _active_mesh_nodes.values():
					if m_node.chunk_name == c_name and m_node.has_method("update_actor_transform"):
						m_node.update_actor_transform(a_name, pos, rot, sc)
						reverted_count += 1
						break

	_pending_actor_fixes.clear()
	return reverted_count


func get_streaming_stats() -> Dictionary:
	var total_actors = 0
	for m_node in _active_mesh_nodes.values():
		if m_node and "_parsed_instances" in m_node and m_node._parsed_instances is Array:
			total_actors += m_node._parsed_instances.size()
	return {
		"active_chunks": _active_terrain_nodes.size(),
		"active_mesh_chunks": _active_mesh_nodes.size(),
		"total_static_actors": total_actors,
	}

