## @file test_chunk_resource_adapter.gd
## @path res://tests/unit/adapters/test_chunk_resource_adapter.gd
##
## @description
## Testes unitários AAA para o adaptador de recursos ChunkResourceAdapter.
##
## @created 2026-08-19
## @updated 2026-08-19
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
