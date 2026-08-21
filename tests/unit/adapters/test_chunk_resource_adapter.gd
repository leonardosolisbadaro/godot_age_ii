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
		"water_volumes": [
			{
				"name": "WaterVolume0",
				"surface_y_m": -320.0,
				"water_plane_height_m": -320.0,
				"size_m": [2621.44, 2621.44],
			},
			{
				"name": "RiverVolume1",
				"surface_y_m": -150.0,
				"water_plane_height_m": -150.0,
				"size_m": [500.0, 1000.0],
			}
		]
	}
	var fix_data = {
		"water_volumes": [
			{
				"name": "WaterVolume0",
				"surface_y_m": -315.0,
				"water_plane_height_m": -315.0,
				"ocean_extension": 2000.0,
			},
			{
				"name": "CustomPondVolume",
				"surface_y_m": -50.0,
				"water_plane_height_m": -50.0,
				"size_m": [200.0, 200.0],
			}
		]
	}

	# Act
	var merged = adapter._apply_water_volumes_fix(raw_data, fix_data)
	var volumes: Array = merged.get("water_volumes", [])

	# Assert
	assert_eq(volumes.size(), 3, "Deve conter 3 volumes (2 originais com 1 override + 1 novo)")
	var wv0 = volumes[0]
	assert_eq(wv0.get("surface_y_m"), -315.0, "Cota de WaterVolume0 deve ser atualizada para -315.0")
	assert_eq(wv0.get("ocean_extension"), 2000.0, "ocean_extension deve ser adicionado ao WaterVolume0")
	var custom_v = volumes[2]
	assert_eq(custom_v.get("name"), "CustomPondVolume", "Novo volume CustomPondVolume deve ser inserido")
	assert_eq(custom_v.get("surface_y_m"), -50.0)


func test_save_and_load_water_volumes_fix_io() -> void:
	# Arrange
	var test_maps_path = "res://tests/scratch/maps"
	var adapter = ChunkResourceAdapterClass.new(test_maps_path)
	var chunk_name = "test_chunk_water"
	var test_fix_data = {
		"water_volumes": [
			{
				"name": "SavedWaterVolume",
				"surface_y_m": -280.0,
				"water_plane_height_m": -280.0,
				"size_m": [1500.0, 1500.0]
			}
		]
	}

	# Act: Salva fix
	var save_ok = adapter.save_water_volumes_fix(chunk_name, test_fix_data)
	assert_true(save_ok, "save_water_volumes_fix deve retornar true")

	# Act: Carrega dict mesclado (sem raw existente, deve carregar o fix)
	var loaded_dict = adapter.load_water_volumes_dict(chunk_name)
	var vols = loaded_dict.get("water_volumes", [])

	# Assert
	assert_false(loaded_dict.is_empty(), "Dicionário carregado não deve ser vazio")
	assert_eq(vols.size(), 1, "Deve conter o volume salvo no fix")
	assert_eq(vols[0].get("name"), "SavedWaterVolume")
	assert_eq(vols[0].get("surface_y_m"), -280.0)

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

