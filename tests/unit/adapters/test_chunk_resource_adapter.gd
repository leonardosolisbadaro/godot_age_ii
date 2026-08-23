## @file test_chunk_resource_adapter.gd
## @path res://tests/unit/adapters/test_chunk_resource_adapter.gd
##
## @description
## Testes unitários AAA para o adaptador de recursos ChunkResourceAdapter.
##
## @created 2026-08-19
## @updated 2026-08-21
##
## @author Leonardo S. Badaró
extends GutTest

const ChunkResourceAdapterClass = preload("res://src/adapters/chunk_resource_adapter.gd")


func test_chunk_exists_and_load_real_metadata() -> void:
	# Arrange
	var adapter = ChunkResourceAdapterClass.new("res://assets/maps")

	# Act & Assert
	assert_true(adapter.chunk_exists("16_24"), "Chunk 16_24 compilado deve existir")
	assert_false(adapter.chunk_exists("non_existing_99_99"), "Chunk inexistente deve retornar falso")

	var server_meta = adapter.load_chunk_meta_dict("16_24", true)
	assert_false(server_meta.is_empty(), "Metadados do servidor devem ser carregados")
	assert_eq(server_meta.get("chunk_name", ""), "16_24")

	var client_meta = adapter.load_chunk_meta_dict("16_24", false)
	assert_false(client_meta.is_empty(), "Metadados do cliente devem ser carregados")


func test_get_available_chunks() -> void:
	# Arrange
	var adapter = ChunkResourceAdapterClass.new("res://assets/maps")

	# Act
	var available = adapter.get_available_chunks()

	# Assert
	assert_gt(available.size(), 0, "Deve encontrar ao menos 1 chunk disponível em assets/maps")
	assert_true("16_24" in available, "Chunk 16_24 deve estar listado nos chunks disponíveis")


func test_load_heightfield_bytes() -> void:
	# Arrange
	var adapter = ChunkResourceAdapterClass.new("res://assets/maps")

	# Act
	var hf_bytes = adapter.load_heightfield_bytes("16_24")

	# Assert (256x256 floats = 65536 * 4 = 262144 bytes)
	assert_eq(hf_bytes.size(), 262144, "Heightfield binário de 256x256 deve ter 262.144 bytes")


func test_load_environment_and_static_actors() -> void:
	# Arrange
	var adapter = ChunkResourceAdapterClass.new("res://assets/maps")

	# Act
	var env_dict = adapter.load_environment_recipe_dict("16_24")
	var actors_arr = adapter.load_static_actors_array("16_24")
	var mats_dict = adapter.load_material_recipes_dict("16_24")

	# Assert
	assert_false(env_dict.is_empty(), "Receita de ambiente deve ser carregada")
	assert_true(env_dict.has("sunlight") or env_dict.has("sun_light"))

	assert_gt(actors_arr.size(), 0, "Atores estáticos devem conter mais de 0 elementos")
	assert_false(mats_dict.is_empty(), "Receitas de materiais devem ser carregadas")


func test_apply_water_volumes_fix_in_memory() -> void:
	# Arrange
	var adapter = ChunkResourceAdapterClass.new("res://assets/maps")
	var raw_data = {
		"water_volumes":
		{
			"WaterVolume0":
			{
				"surface_y_m": -320.0,
				"water_plane_height_m": -320.0,
				"size_m": [2621.44, 2621.44],
			},
			"RiverVolume1":
			{
				"surface_y_m": -150.0,
				"water_plane_height_m": -150.0,
				"size_m": [500.0, 1000.0],
			}
		}
	}
	var fix_data = {
		"water_volumes":
		{
			"WaterVolume0":
			{
				"surface_y_m": -315.0,
				"water_plane_height_m": -315.0,
				"ocean_extension": 2000.0,
			},
			"CustomPondVolume":
			{
				"surface_y_m": -50.0,
				"water_plane_height_m": -50.0,
				"size_m": [200.0, 200.0],
			}
		}
	}

	# Act
	var merged = adapter._apply_water_volumes_fix(raw_data, fix_data)
	var volumes: Dictionary = merged.get("water_volumes", { })

	# Assert
	assert_eq(volumes.size(), 3, "Deve conter 3 volumes (2 originais com 1 override + 1 novo)")
	var wv0 = volumes.get("WaterVolume0", { })
	assert_eq(wv0.get("surface_y_m"), -315.0, "Cota de WaterVolume0 deve ser atualizada para -315.0")
	assert_eq(wv0.get("ocean_extension"), 2000.0, "ocean_extension deve ser adicionado ao WaterVolume0")
	var custom_v = volumes.get("CustomPondVolume", { })
	assert_false(custom_v.is_empty(), "Novo volume CustomPondVolume deve existir no dicionário")
	assert_eq(custom_v.get("surface_y_m"), -50.0)


func test_save_and_load_water_volumes_fix_io() -> void:
	# Arrange
	var test_maps_path = "res://tests/scratch/maps"
	var adapter = ChunkResourceAdapterClass.new(test_maps_path)
	var chunk_name = "test_chunk_water"
	var test_fix_data = {
		"water_volumes":
		{
			"SavedWaterVolume":
			{
				"surface_y_m": -280.0,
				"water_plane_height_m": -280.0,
				"size_m": [1500.0, 1500.0],
			}
		}
	}

	# Act: Salva fix
	var save_ok = adapter.save_water_volumes_fix(chunk_name, test_fix_data)
	assert_true(save_ok, "save_water_volumes_fix deve retornar true")

	# Act: Carrega dict mesclado (sem raw existente, deve carregar o fix)
	var loaded_dict = adapter.load_water_volumes_dict(chunk_name)
	var vols = loaded_dict.get("water_volumes", { })

	# Assert
	assert_false(loaded_dict.is_empty(), "Dicionário carregado não deve ser vazio")
	assert_eq(vols.size(), 1, "Deve conter o volume salvo no fix")
	assert_true(vols.has("SavedWaterVolume"))
	assert_eq(vols["SavedWaterVolume"].get("surface_y_m"), -280.0)

	# Cleanup
	var fix_file = "%s/%s/water_volumes_fix.json" % [test_maps_path, chunk_name]
	var glob_f = ProjectSettings.globalize_path(fix_file)
	if FileAccess.file_exists(glob_f):
		DirAccess.remove_absolute(glob_f)


func test_load_collision_rules_dict() -> void:
	# Arrange
	var adapter = ChunkResourceAdapterClass.new("res://assets/maps")

	# Act
	var rules = adapter.load_collision_rules_dict()

	# Assert
	assert_false(rules.is_empty(), "static_mesh_collision_rules.json deve ser carregado com sucesso")
	assert_true(rules.has("categories"), "Deve conter a chave 'categories'")
	assert_true(rules.has("custom_overrides"), "Deve conter a chave 'custom_overrides'")


func test_save_and_load_static_actors_fix_io() -> void:
	# Arrange
	var test_maps_path = "res://assets/maps"
	var adapter = ChunkResourceAdapterClass.new(test_maps_path)
	var chunk_name = "test_chunk_actors_fix_tmp"
	var fix_data = {
		"actors":
		{
			"StaticMeshActorTest":
			{
				"actor_name": "StaticMeshActorTest",
				"transform":
				{
					"location_meters": [10.0, -280.0, 50.0],
					"rotation_degrees": [0.0, 90.0, 0.0],
					"scale": [1.0, 1.0, 1.0],
				}
			}
		}
	}

	# Act: Salva no disco
	var save_ok = adapter.save_static_actors_fix(chunk_name, fix_data)
	assert_true(save_ok, "save_static_actors_fix deve retornar true")

	# Act: Carrega do disco
	var loaded = adapter.load_static_actors_fix_dict(chunk_name)
	assert_false(loaded.is_empty(), "load_static_actors_fix_dict deve carregar o dicionário")
	assert_true(loaded.has("actors"), "Deve conter a chave 'actors'")

	# Cleanup
	var fix_file = "%s/%s/chunk_static_actors_fix.json" % [test_maps_path, chunk_name]
	var glob_f = ProjectSettings.globalize_path(fix_file)
	if FileAccess.file_exists(glob_f):
		DirAccess.remove_absolute(glob_f)
	var dir_f = glob_f.get_base_dir()
	if DirAccess.dir_exists_absolute(dir_f):
		DirAccess.remove_absolute(dir_f)


func test_load_static_actors_dict_format() -> void:
	# Arrange
	var test_maps_path = "res://assets/maps"
	var adapter = ChunkResourceAdapterClass.new(test_maps_path)
	var chunk_name = "test_chunk_dict_actors_tmp"
	var json_file = "%s/%s/chunk_static_actors.json" % [test_maps_path, chunk_name]
	var glob_f = ProjectSettings.globalize_path(json_file)
	var dir_f = glob_f.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_f):
		DirAccess.make_dir_recursive_absolute(dir_f)

	var mock_meta = {
		"chunk_name": chunk_name,
		"total_actors": 2,
		"actors":
		{
			"ActorAlpha":
			{
				"transform":
				{
					"location_meters": [10.0, -200.0, 30.0],
				}
			},
			"ActorBeta":
			{
				"transform":
				{
					"location_meters": [40.0, -200.0, 60.0],
				}
			}
		}
	}
	var f = FileAccess.open(glob_f, FileAccess.WRITE)
	f.store_string(JSON.stringify(mock_meta, "\t"))
	f.close()

	# Act
	var loaded_actors = adapter.load_static_actors_array(chunk_name)

	# Assert
	assert_eq(loaded_actors.size(), 2, "Deve carregar os 2 atores do dicionário")
	var names: Array = []
	for a in loaded_actors:
		names.append(a.get("actor_name", ""))
	assert_true(names.has("ActorAlpha"), "Deve conter ActorAlpha")
	assert_true(names.has("ActorBeta"), "Deve conter ActorBeta")

	# Cleanup
	if FileAccess.file_exists(glob_f):
		DirAccess.remove_absolute(glob_f)
	if DirAccess.dir_exists_absolute(dir_f):
		DirAccess.remove_absolute(dir_f)


func test_apply_water_volumes_fix_dict_format() -> void:
	# Arrange
	var adapter = ChunkResourceAdapterClass.new("res://assets/maps")
	var raw_data = {
		"water_volumes":
		{
			"WaterVolume0":
			{
				"surface_y_m": -320.0,
				"size_m": [2621.44, 2621.44],
			}
		}
	}
	var fix_data = {
		"water_volumes":
		{
			"WaterVolume0":
			{
				"surface_y_m": -310.0,
				"ocean_extension": 1500.0,
			},
			"NewPond":
			{
				"surface_y_m": -50.0,
				"size_m": [200.0, 200.0],
			}
		}
	}

	# Act
	var merged = adapter._apply_water_volumes_fix(raw_data, fix_data)
	var volumes: Dictionary = merged.get("water_volumes", { })

	# Assert
	assert_eq(volumes.size(), 2, "Deve conter 2 volumes")
	assert_true(volumes.has("WaterVolume0"))
	assert_eq(volumes["WaterVolume0"].get("surface_y_m"), -310.0, "Cota deve ser sobrescrita pelo fix")
	assert_eq(volumes["WaterVolume0"].get("ocean_extension"), 1500.0)
	assert_true(volumes.has("NewPond"))
	assert_eq(volumes["NewPond"].get("surface_y_m"), -50.0)


func test_save_collision_override_io() -> void:
	# Arrange
	var test_maps_path = "res://tests/scratch/maps"
	var adapter = ChunkResourceAdapterClass.new(test_maps_path)
	var package_name = "test_village_pkg"
	var mesh_name = "test_gate_mesh"
	var collision_type = "concave"

	# Act
	var saved = adapter.save_collision_override(package_name, mesh_name, collision_type)
	var loaded_rules = adapter.load_collision_rules_dict()
	var overrides = loaded_rules.get("custom_overrides", { })

	# Assert
	assert_true(saved, "save_collision_override deve retornar true ao salvar com sucesso")
	assert_true(overrides.has("test_village_pkg.test_gate_mesh"), "custom_overrides deve conter a chave do pacote.modelo")
	assert_eq(overrides["test_village_pkg.test_gate_mesh"].get("type"), "concave")


func test_load_and_save_world_teleports_io() -> void:
	# Arrange
	var test_maps_path = "res://tests/scratch/maps"
	var adapter = ChunkResourceAdapterClass.new(test_maps_path)
	var tp_name = "Ponto de Teste Torre"
	var tp_pos = Vector3(-4500.0, -220.0, 21000.0)
	var tp_chunk = "17_25"

	# Act
	var saved = adapter.save_world_teleport(tp_name, tp_pos, tp_chunk)
	var teleports = adapter.load_world_teleports()

	# Assert
	assert_true(saved, "save_world_teleport deve retornar true ao gravar")
	assert_gt(teleports.size(), 0, "Deve conter ao menos 1 teleporte gravado")

	var found_entry: Dictionary = {}
	for entry in teleports:
		if entry.get("name") == tp_name:
			found_entry = entry
			break

	assert_false(found_entry.is_empty(), "O teleporte 'Ponto de Teste Torre' deve existir")
	assert_eq(found_entry.get("chunk_name"), "17_25")
	assert_eq(found_entry.get("position"), [-4500.0, -220.0, 21000.0])

	# Cleanup
	var tp_file = "%s/world_teleports.json" % test_maps_path
	var glob_f = ProjectSettings.globalize_path(tp_file)
	if FileAccess.file_exists(glob_f):
		DirAccess.remove_absolute(glob_f)


