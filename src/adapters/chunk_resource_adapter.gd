## @file chunk_resource_adapter.gd
## @path res://src/adapters/chunk_resource_adapter.gd
##
## @description
## Adaptador de interface e IO para leitura, descoberta automática e carregamento
## de artefatos de mapa, metadados, heightfields, atores estáticos e receitas de ambiente.
##
## @created 2026-08-19
## @updated 2026-08-21
##
## @author Leonardo S. Badaró
extends RefCounted

# ==============================================================================
# CONSTANTES SEMÂNTICAS DE RECURSOS
# ==============================================================================

## @const DEFAULT_BASE_MAPS_PATH (String)
## O que: Caminho padrão do repositório de dados de mapa compilados ("res://assets/maps").
## Porque: Localização canônica de assets do projeto.
const DEFAULT_BASE_MAPS_PATH: String = "res://assets/maps"

var base_maps_path: String = DEFAULT_BASE_MAPS_PATH


func _init(p_base_path: String = DEFAULT_BASE_MAPS_PATH) -> void:
	base_maps_path = p_base_path


func chunk_exists(chunk_name: String) -> bool:
	var path = "%s/%s" % [base_maps_path, chunk_name]
	var global_p = ProjectSettings.globalize_path(path)
	return DirAccess.dir_exists_absolute(path) or DirAccess.dir_exists_absolute(global_p)


func get_available_chunks() -> Array[String]:
	var result: Array[String] = []
	var path = base_maps_path
	var global_p = ProjectSettings.globalize_path(path)
	var target_dir = path if DirAccess.dir_exists_absolute(path) else global_p

	var dir = DirAccess.open(target_dir)
	if dir:
		dir.list_dir_begin()
		var entry = dir.get_next()
		while not entry.is_empty():
			if dir.current_is_dir() and not entry.begins_with("."):
				# Valida se é um diretório de chunk com dados de servidor ou cliente
				if chunk_exists(entry):
					result.append(entry)
			entry = dir.get_next()
		dir.list_dir_end()

	result.sort()
	return result


func load_chunk_meta_dict(chunk_name: String, is_server: bool = true) -> Dictionary:
	if is_server:
		var path = "%s/%s/server/chunk_meta.json" % [base_maps_path, chunk_name]
		return _read_json_as_dict(path)
	else:
		var client_recipe_path = "%s/%s/client/terrain_recipe.json" % [base_maps_path, chunk_name]
		var dict = _read_json_as_dict(client_recipe_path)
		if dict.is_empty():
			var fallback_path = "%s/%s/client/chunk_meta.json" % [base_maps_path, chunk_name]
			dict = _read_json_as_dict(fallback_path)

		# Aplica overrides de terrain_recipe_fix.json se existir
		var fix_root = "%s/%s/terrain_recipe_fix.json" % [base_maps_path, chunk_name]
		var fix_client = "%s/%s/client/terrain_recipe_fix.json" % [base_maps_path, chunk_name]
		var fix_path = fix_root if _file_exists(fix_root) else fix_client
		if _file_exists(fix_path):
			var fix_data = _read_json_as_dict(fix_path)
			dict = _apply_terrain_recipe_fix(dict, fix_data)

		return dict


func _apply_terrain_recipe_fix(recipe_dict: Dictionary, fix_dict: Dictionary) -> Dictionary:
	if not recipe_dict.has("layers") or not (recipe_dict["layers"] is Array):
		return recipe_dict

	var layers_fix = fix_dict.get("layers", { })
	if not (layers_fix is Dictionary):
		return recipe_dict

	for layer in recipe_dict["layers"]:
		if not (layer is Dictionary):
			continue
		var l_idx = str(layer.get("layer_index", -1))
		var tex_f = str(layer.get("texture_file", ""))

		# Verifica match por chave de textura ou índice de camada
		for fix_key in layers_fix.keys():
			if fix_key in tex_f or fix_key == l_idx:
				var override = layers_fix[fix_key]
				if override is Dictionary:
					for k in override.keys():
						layer[k] = override[k]

	return recipe_dict


func load_heightfield_bytes(chunk_name: String) -> PackedByteArray:
	var path = "%s/%s/server/heightfield.bin" % [base_maps_path, chunk_name]
	var target = _resolve_existing_path(path)
	if target.is_empty():
		return PackedByteArray()

	var file = FileAccess.open(target, FileAccess.READ)
	if not file:
		return PackedByteArray()

	var data = file.get_buffer(file.get_length())
	file.close()
	return data


func load_environment_recipe_dict(chunk_name: String) -> Dictionary:
	var path = "%s/%s/client/environment_recipe.json" % [base_maps_path, chunk_name]
	return _read_json_as_dict(path)


func load_water_volumes_dict(chunk_name: String) -> Dictionary:
	var path_root = "%s/%s/water_volumes.json" % [base_maps_path, chunk_name]
	var path_server = "%s/%s/server/water_volumes.json" % [base_maps_path, chunk_name]
	var path = path_root if _file_exists(path_root) else path_server

	var data = _read_json_as_dict(path)
	if not data.has("water_volumes") or not (data["water_volumes"] is Dictionary):
		data["water_volumes"] = { }

	var fix_root = "%s/%s/water_volumes_fix.json" % [base_maps_path, chunk_name]
	var fix_client = "%s/%s/client/water_volumes_fix.json" % [base_maps_path, chunk_name]
	var fix_path = ""
	if _file_exists(fix_root):
		fix_path = fix_root
	elif _file_exists(fix_client):
		fix_path = fix_client

	if not fix_path.is_empty():
		var fix_data = _read_json_as_dict(fix_path)
		data = _apply_water_volumes_fix(data, fix_data)

	return data


func _apply_water_volumes_fix(water_data: Dictionary, fix_data: Dictionary) -> Dictionary:
	var volumes_dict: Dictionary = water_data.get("water_volumes", { })
	if not (volumes_dict is Dictionary):
		volumes_dict = { }

	var fix_volumes_dict: Dictionary = fix_data.get("water_volumes", { })
	if not (fix_volumes_dict is Dictionary):
		return water_data

	for v_name in fix_volumes_dict.keys():
		var override = fix_volumes_dict[v_name]
		if not (override is Dictionary):
			continue
		if not volumes_dict.has(v_name):
			volumes_dict[v_name] = override.duplicate(true)
		else:
			for k in override.keys():
				volumes_dict[v_name][k] = override[k]

	water_data["water_volumes"] = volumes_dict
	return water_data


func save_water_volumes_fix(chunk_name: String, fix_data: Dictionary) -> bool:
	var fix_path = "%s/%s/water_volumes_fix.json" % [base_maps_path, chunk_name]
	var target = _resolve_write_path(fix_path)
	if target.is_empty():
		return false

	var dir_path = target.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var file = FileAccess.open(target, FileAccess.WRITE)
	if not file:
		return false

	var json_str = JSON.stringify(fix_data, "\t")
	file.store_string(json_str)
	file.close()
	return true


func load_static_actors_array(
	chunk_name: String,
	is_server: bool = false,
	apply_fix: bool = true
) -> Array:
	var root_path = "%s/%s/chunk_static_actors.json" % [base_maps_path, chunk_name]
	var subfolder = "server" if is_server else "client"
	var sub_path = "%s/%s/%s/chunk_static_actors.json" % [base_maps_path, chunk_name, subfolder]

	var main_path = root_path if _file_exists(root_path) else sub_path
	var data = _read_json_as_dict(main_path)
	var raw_actors: Dictionary = data.get("actors", { })
	if not (raw_actors is Dictionary):
		raw_actors = { }

	var fix_actors: Dictionary = { }
	if apply_fix:
		var fix_root = "%s/%s/chunk_static_actors_fix.json" % [base_maps_path, chunk_name]
		var fix_client = "%s/%s/client/chunk_static_actors_fix.json" % [base_maps_path, chunk_name]
		var fix_path = fix_root if _file_exists(fix_root) else fix_client
		if _file_exists(fix_path):
			var fix_data = _read_json_as_dict(fix_path)
			var f_acts = fix_data.get("actors", { })
			if f_acts is Dictionary:
				fix_actors = f_acts

	var actors: Array = []
	for a_name in raw_actors.keys():
		var a_dict = raw_actors[a_name]
		if not (a_dict is Dictionary):
			continue
		var a = a_dict.duplicate(true)
		a["actor_name"] = str(a_name)

		if fix_actors.has(a_name):
			var override = fix_actors[a_name]
			if override is Dictionary:
				if not a.has("transform"):
					a["transform"] = { }
				if override.has("transform") and override["transform"] is Dictionary:
					for k in override["transform"].keys():
						a["transform"][k] = override["transform"][k]
						if k == "location_meters":
							a["transform"]["position_meters"] = override["transform"][k]
						elif k == "position_meters":
							a["transform"]["location_meters"] = override["transform"][k]
						elif k == "rotation_degrees":
							var deg_arr = override["transform"][k]
							if deg_arr is Array and deg_arr.size() >= 3:
								a["transform"]["rotation_euler_rad"] = [
									deg_to_rad(float(deg_arr[0])),
									deg_to_rad(float(deg_arr[1])),
									deg_to_rad(float(deg_arr[2])),
								]
				elif override.has("location_meters"):
					var loc = override.get("location_meters", [])
					if loc is Array:
						a["transform"]["location_meters"] = loc
						a["transform"]["position_meters"] = loc
				if override.has("mesh_ref"):
					a["mesh_ref"] = override["mesh_ref"]

		actors.append(a)

	return actors


func load_static_actors_fix_dict(chunk_name: String) -> Dictionary:
	var fix_root = "%s/%s/chunk_static_actors_fix.json" % [base_maps_path, chunk_name]
	var fix_client = "%s/%s/client/chunk_static_actors_fix.json" % [base_maps_path, chunk_name]
	var fix_path = fix_root if _file_exists(fix_root) else fix_client
	if not _file_exists(fix_path):
		return { }
	return _read_json_as_dict(fix_path)


func save_static_actors_fix(chunk_name: String, fix_data: Dictionary) -> bool:
	var fix_path = "%s/%s/chunk_static_actors_fix.json" % [base_maps_path, chunk_name]
	var target = _resolve_write_path(fix_path)
	if target.is_empty():
		return false

	var dir_path = target.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var file = FileAccess.open(target, FileAccess.WRITE)
	if not file:
		return false

	var json_str = JSON.stringify(fix_data, "\t")
	file.store_string(json_str)
	file.close()
	return true


func load_material_recipes_dict(chunk_name: String) -> Dictionary:
	var path = "%s/%s/client/material_recipes.json" % [base_maps_path, chunk_name]
	return _read_json_as_dict(path)


func _file_exists(path: String) -> bool:
	if path.is_empty():
		return false
	return (
		FileAccess.file_exists(path) or FileAccess.file_exists(ProjectSettings.globalize_path(path))
	)


func _resolve_existing_path(path: String) -> String:
	if path.is_empty():
		return ""
	if FileAccess.file_exists(path):
		return path
	var glob = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(glob):
		return glob
	return ""


func _resolve_write_path(path: String) -> String:
	if path.is_empty():
		return ""
	var glob = ProjectSettings.globalize_path(path)
	if not glob.is_empty():
		return glob
	return path


func _read_json_as_dict(path: String) -> Dictionary:
	var target = _resolve_existing_path(path)
	if target.is_empty():
		return { }

	var file = FileAccess.open(target, FileAccess.READ)
	if not file:
		return { }

	var text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var err = json.parse(text)
	if err == OK and json.data is Dictionary:
		return json.data
	return { }


func _read_json_raw(path: String) -> Variant:
	var target = _resolve_existing_path(path)
	if target.is_empty():
		return null

	var file = FileAccess.open(target, FileAccess.READ)
	if not file:
		return null

	var text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var err = json.parse(text)
	if err == OK:
		return json.data
	return null


func load_collision_rules_dict() -> Dictionary:
	var path = "%s/static_mesh_collision_rules.json" % base_maps_path
	return _read_json_as_dict(path)
