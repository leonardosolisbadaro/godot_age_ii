## @file chunk_resource_adapter.gd
## @path res://src/client/adapters/chunk_resource_adapter.gd
##
## @description
## Adaptador de infraestrutura responsavel por ler e desserializar de forma desacoplada
## os arquivos brutos de mapas (binarios de altura, imagens de splatmap, receitas JSON,
## atores estaticos e corpos d'agua) armazenados em 'res://assets/maps/'.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
class_name ChunkResourceAdapter
extends RefCounted

# ==============================================================================
# DEPENDÊNCIAS PRELOAD
# ==============================================================================

const WaterVolumeDataClass = preload("res://src/core/domain/water_volume_data.gd")
const EnvironmentZoneDataClass = preload("res://src/core/domain/environment_zone_data.gd")
const ScaleConverterClass = preload("res://src/core/domain/scale_converter.gd")

# ==============================================================================
# CONSTANTES DE CAMINHO
# ==============================================================================

const BASE_MAPS_PATH: String = "res://assets/maps"
const BASE_MODELS_PATH: String = "res://assets/models"

# ==============================================================================
# AUTODESCOBERTA E LEITURA DE CHUNKS
# ==============================================================================


## Retorna a lista de nomes de chunks disponíveis no diretório assets/maps/ (ex: ["16_24", "16_25", ...]).
static func get_available_chunks(base_path: String = BASE_MAPS_PATH) -> Array[String]:
	var results: Array[String] = []
	var dir = DirAccess.open(base_path)
	if dir == null:
		return results

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			var parts = file_name.split("_")
			if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
				results.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	results.sort()
	return results


## Carrega a matriz binária de alturas heightfield.bin (formato Float32 Little-Endian 256x256).
static func load_heightfield_floats(chunk_name: String, base_path: String = BASE_MAPS_PATH) -> PackedFloat32Array:
	var file_path = "%s/%s/server/heightfield.bin" % [base_path, chunk_name]
	if not FileAccess.file_exists(file_path):
		return PackedFloat32Array()

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return PackedFloat32Array()

	var buffer = file.get_buffer(file.get_length())
	file.close()

	return buffer.to_float32_array()


## Carrega a textura de heightmap 16-bit (PNG) para a malha do terreno no cliente.
static func load_heightmap_texture(chunk_name: String, base_path: String = BASE_MAPS_PATH) -> Texture2D:
	var path = "%s/%s/client/heightmap_16bit.png" % [base_path, chunk_name]
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


## Carrega todos os splatmaps disponíveis para um chunk (splatmap_0.png, splatmap_1.png, etc.).
static func load_splatmaps(chunk_name: String, base_path: String = BASE_MAPS_PATH) -> Array[Texture2D]:
	var splatmaps: Array[Texture2D] = []
	for i in range(4):
		var path = "%s/%s/client/splatmap_%d.png" % [base_path, chunk_name, i]
		if ResourceLoader.exists(path):
			var tex = load(path) as Texture2D
			if tex != null:
				splatmaps.append(tex)
		else:
			break
	return splatmaps


## Carrega o arquivo JSON de metadados do servidor (chunk_meta.json).
static func load_chunk_meta(chunk_name: String, base_path: String = BASE_MAPS_PATH) -> Dictionary:
	var path = "%s/%s/server/chunk_meta.json" % [base_path, chunk_name]
	return _read_json_file(path)


## Carrega a lista normalizada de atores e malhas estáticas (chunk_static_actors.json).
static func load_static_actors(chunk_name: String, base_path: String = BASE_MAPS_PATH) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var path = "%s/%s/chunk_static_actors.json" % [base_path, chunk_name]
	var dict = _read_json_file(path)
	if not dict.has("actors"):
		return results

	# Formato 1: Dicionário indexado por nome do ator
	if dict["actors"] is Dictionary:
		var actors_dict: Dictionary = dict["actors"]
		for actor_name in actors_dict.keys():
			var a = actors_dict[actor_name]
			if not (a is Dictionary):
				continue
			var m_ref = a.get("mesh_ref", { })
			var pkg = str(m_ref.get("package", "")).to_lower()
			var obj = str(m_ref.get("object_name", "")).to_lower()
			var transform = a.get("transform", { })

			var resolved_path = _resolve_mesh_path(pkg, obj)
			if resolved_path.is_empty():
				continue

			results.append(
				{
					"actor_name": str(actor_name),
					"mesh_path": resolved_path,
					"position": transform.get("position_meters", [0.0, 0.0, 0.0]),
					"rotation_rad": transform.get("rotation_euler_rad", [0.0, 0.0, 0.0]),
					"scale": transform.get("scale", [1.0, 1.0, 1.0]),
				}
			)
		return results

	# Formato 2: Array de atores
	if dict["actors"] is Array:
		for a in dict["actors"]:
			if a is Dictionary:
				results.append(a)

	return results


## Carrega os volumes de água definidos para um chunk (water_volumes.json).
static func load_water_volumes(chunk_name: String, base_path: String = BASE_MAPS_PATH) -> Array[WaterVolumeDataClass]:
	var results: Array[WaterVolumeDataClass] = []
	var path = "%s/%s/water_volumes.json" % [base_path, chunk_name]
	var dict = _read_json_file(path)
	if dict.is_empty():
		return results

	if dict.has("water_volumes") and dict["water_volumes"] is Dictionary:
		var wv_dict: Dictionary = dict["water_volumes"]
		for vol_id in wv_dict.keys():
			var v = wv_dict[vol_id]
			if v is Dictionary:
				var surface_y = float(v.get("surface_y_m", v.get("water_plane_height_m", 0.0)))
				var bottom_y = float(v.get("bottom_y_m", surface_y - 10.0))
				var size_arr = v.get("size_m", [2621.44, 2621.44])
				var center_arr = v.get("center_m", [0.0, 0.0])
				var size_x = float(size_arr[0]) if size_arr is Array and size_arr.size() > 0 else 2621.44
				var size_z = float(size_arr[1]) if size_arr is Array and size_arr.size() > 1 else 2621.44
				var center_x = float(center_arr[0]) if center_arr is Array and center_arr.size() > 0 else 0.0
				var center_z = float(center_arr[1]) if center_arr is Array and center_arr.size() > 1 else 0.0

				var pos = Vector3(center_x - (size_x * 0.5), bottom_y, center_z - (size_z * 0.5))
				var size = Vector3(size_x, maxf(surface_y - bottom_y, 1.0), size_z)
				var aabb = AABB(pos, size)
				results.append(WaterVolumeDataClass.new(str(vol_id), surface_y, aabb, "OCEAN"))
		return results

	return results


## Carrega a receita de ambiente e iluminação (environment_recipe.json).
static func load_environment_zone(chunk_name: String, base_path: String = BASE_MAPS_PATH) -> EnvironmentZoneDataClass:
	var path = "%s/%s/client/environment_recipe.json" % [base_path, chunk_name]
	var dict = _read_json_file(path)
	if dict.is_empty():
		return EnvironmentZoneDataClass.new()

	var sun_c = _parse_color(dict.get("sun_color", null), Color(1.0, 0.95, 0.85))
	var amb_c = _parse_color(dict.get("ambient_color", null), Color(0.25, 0.30, 0.40))
	var fog_c = _parse_color(dict.get("fog_color", null), Color(0.60, 0.70, 0.80))
	var fog_d = float(dict.get("fog_density", 0.001))

	var sun_dir = Vector3(-0.5, -0.8, -0.3)
	if (
		dict.has("sun_direction") and dict["sun_direction"] is Array
		and dict["sun_direction"].size() >= 3
	):
		sun_dir = Vector3(
			dict["sun_direction"][0],
			dict["sun_direction"][1],
			dict["sun_direction"][2],
		)

	return EnvironmentZoneDataClass.new(sun_c, amb_c, fog_c, fog_d, sun_dir)


const BASE_TEXTURES_PATH: String = "res://assets/textures"

# ==============================================================================
# MÉTODOS AUXILIARES DE PARSER E RESOLUÇÃO DE ASSETS
# ==============================================================================

static var _package_dirs_cache: Dictionary = { } # { "lowercase_pkg": "Actual_Pkg" }
static var _models_casing_cache: Dictionary = { } # { "pkg": { "lowercase_obj": "res://assets/models/Actual_Pkg/Actual_Obj.glb" } }
static var _texture_pkg_dirs_cache: Dictionary = { } # { "lowercase_pkg": "Actual_Pkg" }
static var _textures_casing_cache: Dictionary = { } # { "pkg": { "lowercase_obj": "res://assets/textures/Actual_Pkg/Actual_Obj.png" } }


## Carrega o dicionário de receitas de materiais do chunk (material_recipes.json).
static func load_material_recipes(chunk_name: String, base_path: String = BASE_MAPS_PATH) -> Dictionary:
	var path = "%s/%s/client/material_recipes.json" % [base_path, chunk_name]
	return _read_json_file(path)


## Resolve o caminho absoluto exato de uma textura no sistema de arquivos.
static func resolve_texture_path(tex_path_or_recipe_path: String) -> String:
	if tex_path_or_recipe_path.is_empty():
		return ""

	var clean_path = tex_path_or_recipe_path.replace("\\", "/").strip_edges()
	var package = ""
	var file_name = ""

	if "assets/textures/" in clean_path:
		var idx = clean_path.find("assets/textures/") + "assets/textures/".length()
		var sub = clean_path.substr(idx)
		var parts = sub.split("/")
		if parts.size() >= 2:
			package = parts[0]
			file_name = parts[1]
		elif parts.size() == 1:
			file_name = parts[0]
	elif "." in clean_path:
		var parts = clean_path.split(".")
		if parts.size() == 2 and not parts[1].to_lower() in ["png", "jpg", "dds", "tga"]:
			package = parts[0]
			file_name = parts[1] + ".png"
		else:
			file_name = clean_path if clean_path.ends_with(".png") else clean_path + ".png"
	else:
		file_name = clean_path + ".png"

	# 1. Inicializa o cache de pastas de texturas
	if _texture_pkg_dirs_cache.is_empty():
		var base_dir = DirAccess.open(BASE_TEXTURES_PATH)
		if base_dir != null:
			base_dir.list_dir_begin()
			var d_name = base_dir.get_next()
			while not d_name.is_empty():
				if base_dir.current_is_dir() and not d_name.begins_with("."):
					_texture_pkg_dirs_cache[d_name.to_lower()] = d_name
				d_name = base_dir.get_next()
			base_dir.list_dir_end()

	var pkg_key = package.to_lower()
	var obj_key = file_name.get_basename().to_lower()

	# 2. Busca no pacote especificado se conhecido
	if not pkg_key.is_empty() and _texture_pkg_dirs_cache.has(pkg_key):
		var actual_pkg: String = _texture_pkg_dirs_cache[pkg_key]
		if not _textures_casing_cache.has(pkg_key):
			_index_texture_package(pkg_key, actual_pkg)
		var pkg_files: Dictionary = _textures_casing_cache[pkg_key]
		if pkg_files.has(obj_key):
			return pkg_files[obj_key]

	# 3. Fallback: busca em todos os pacotes indexados
	for p_key in _texture_pkg_dirs_cache.keys():
		var actual_pkg: String = _texture_pkg_dirs_cache[p_key]
		if not _textures_casing_cache.has(p_key):
			_index_texture_package(p_key, actual_pkg)
		var pkg_files: Dictionary = _textures_casing_cache[p_key]
		if pkg_files.has(obj_key):
			return pkg_files[obj_key]

	return ""


static func _index_texture_package(pkg_key: String, actual_pkg: String) -> void:
	var files_map: Dictionary = { }
	var pkg_path = "%s/%s" % [BASE_TEXTURES_PATH, actual_pkg]
	var dir = DirAccess.open(pkg_path)
	if dir != null:
		dir.list_dir_begin()
		var fn = dir.get_next()
		while not fn.is_empty():
			if not dir.current_is_dir() and fn.ends_with(".png"):
				files_map[fn.get_basename().to_lower()] = "%s/%s" % [pkg_path, fn]
			fn = dir.get_next()
		dir.list_dir_end()
	_textures_casing_cache[pkg_key] = files_map


static func _resolve_mesh_path(package: String, object_name: String) -> String:
	var pkg_key = package.to_lower()
	var obj_key = object_name.to_lower()

	# 1. Carrega o cache de pastas de pacotes se ainda não foi inicializado
	if _package_dirs_cache.is_empty():
		var base_dir = DirAccess.open(BASE_MODELS_PATH)
		if base_dir != null:
			base_dir.list_dir_begin()
			var d_name = base_dir.get_next()
			while not d_name.is_empty():
				if base_dir.current_is_dir() and not d_name.begins_with("."):
					_package_dirs_cache[d_name.to_lower()] = d_name
				d_name = base_dir.get_next()
			base_dir.list_dir_end()

	if not _package_dirs_cache.has(pkg_key):
		return ""

	var actual_pkg_name: String = _package_dirs_cache[pkg_key]

	# 2. Carrega o cache de arquivos .glb do pacote se ainda não foi indexado
	if not _models_casing_cache.has(pkg_key):
		var files_map: Dictionary = { }
		var pkg_path = "%s/%s" % [BASE_MODELS_PATH, actual_pkg_name]
		var pkg_dir = DirAccess.open(pkg_path)
		if pkg_dir != null:
			pkg_dir.list_dir_begin()
			var fn = pkg_dir.get_next()
			while not fn.is_empty():
				if not pkg_dir.current_is_dir() and fn.ends_with(".glb"):
					var base_fn = fn.get_basename().to_lower()
					files_map[base_fn] = "%s/%s" % [pkg_path, fn]
				fn = pkg_dir.get_next()
			pkg_dir.list_dir_end()
		_models_casing_cache[pkg_key] = files_map

	var pkg_files: Dictionary = _models_casing_cache[pkg_key]
	return pkg_files.get(obj_key, "")


static func _read_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return { }
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return { }
	var text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var err = json.parse(text)
	if err == OK and json.data is Dictionary:
		return json.data
	return { }


static func _parse_color(val, default_val: Color) -> Color:
	if val == null:
		return default_val
	if val is Array and val.size() >= 3:
		var a = val[3] if val.size() >= 4 else 1.0
		return Color(val[0], val[1], val[2], a)
	return default_val
