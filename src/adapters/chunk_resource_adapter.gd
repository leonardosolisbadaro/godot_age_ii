## @file chunk_resource_adapter.gd
## @path res://src/adapters/chunk_resource_adapter.gd
##
## @description
## Adaptador de interface e IO para leitura e carregamento de artefatos de mapa,
## metadados, heightfields, atores estáticos, receitas de ambiente e materiais do disco.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends RefCounted

var base_maps_path: String = "res://assets/maps"


func _init(p_base_path: String = "res://assets/maps") -> void:
	base_maps_path = p_base_path


func chunk_exists(chunk_name: String) -> bool:
	var path = "%s/%s" % [base_maps_path, chunk_name]
	return DirAccess.dir_exists_absolute(path)


func load_chunk_meta_dict(chunk_name: String, is_server: bool = true) -> Dictionary:
	if is_server:
		var path = "%s/%s/server/chunk_meta.json" % [base_maps_path, chunk_name]
		return _read_json_as_dict(path)
	else:
		var client_recipe_path = "%s/%s/client/terrain_recipe.json" % [base_maps_path, chunk_name]
		var dict = _read_json_as_dict(client_recipe_path)
		if not dict.is_empty():
			return dict
		var fallback_path = "%s/%s/client/chunk_meta.json" % [base_maps_path, chunk_name]
		return _read_json_as_dict(fallback_path)


func load_heightfield_bytes(chunk_name: String) -> PackedByteArray:
	var path = "%s/%s/server/heightfield.bin" % [base_maps_path, chunk_name]
	if not FileAccess.file_exists(path):
		return PackedByteArray()

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return PackedByteArray()

	var data = file.get_buffer(file.get_length())
	file.close()
	return data


func load_environment_recipe_dict(chunk_name: String) -> Dictionary:
	var path = "%s/%s/client/environment_recipe.json" % [base_maps_path, chunk_name]
	return _read_json_as_dict(path)


func load_static_actors_array(chunk_name: String, is_server: bool = false) -> Array:
	var subfolder = "server" if is_server else "client"
	var path = "%s/%s/%s/chunk_static_actors.json" % [base_maps_path, chunk_name, subfolder]
	var data = _read_json_raw(path)
	if data is Array:
		return data
	elif data is Dictionary and data.has("actors") and data["actors"] is Array:
		return data["actors"]
	return []


func load_material_recipes_dict(chunk_name: String) -> Dictionary:
	var path = "%s/%s/client/material_recipes.json" % [base_maps_path, chunk_name]
	return _read_json_as_dict(path)


func _read_json_as_dict(path: String) -> Dictionary:
	var parsed = _read_json_raw(path)
	if parsed is Dictionary:
		return parsed
	return {}


func _read_json_raw(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return null

	var text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var err = json.parse(text)
	if err != OK:
		return null

	return json.data
