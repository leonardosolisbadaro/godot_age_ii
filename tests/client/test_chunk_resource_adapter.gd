## @file test_chunk_resource_adapter.gd
## @path res://tests/client/test_chunk_resource_adapter.gd
##
## @description
## Testes unitarios GUT AAA do ChunkResourceAdapter.
## Valida autodescoberta de chunks em assets/maps e leitura de binarios, atores e jsons.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
extends GutTest

const ChunkResourceAdapterClass = preload("res://src/client/adapters/chunk_resource_adapter.gd")


func test_get_available_chunks() -> void:
	# Act
	var chunks = ChunkResourceAdapterClass.get_available_chunks()

	# Assert
	assert_gt(chunks.size(), 0, "Deve encontrar pelo menos um chunk em assets/maps.")
	assert_true(chunks.has("16_24"), "Chunk 16_24 (Talking Island) deve estar disponivel.")


func test_load_heightfield_floats() -> void:
	# Act
	var heights = ChunkResourceAdapterClass.load_heightfield_floats("16_24")

	# Assert
	assert_gt(heights.size(), 0, "Matriz de alturas deve ter dados.")
	assert_eq(
		heights.size(),
		256 * 256,
		"Heightfield deve conter exatamente 65536 amostras (256x256).",
	)


func test_load_water_volumes() -> void:
	# Act
	var waters = ChunkResourceAdapterClass.load_water_volumes("16_24")

	# Assert
	assert_gt(waters.size(), 0, "Chunk 16_24 deve possuir corpos d'agua.")
	assert_not_null(waters[0].bounds_aabb, "AABB do corpo d'agua deve ser valida.")


func test_load_environment_zone() -> void:
	# Act
	var env = ChunkResourceAdapterClass.load_environment_zone("16_24")

	# Assert
	assert_not_null(env, "Ambiente do chunk 16_24 deve ser carregado.")
	assert_gt(env.fog_density, 0.0, "Densidade de neblina deve ser maior que 0.")


func test_load_static_actors() -> void:
	# Act
	var actors = ChunkResourceAdapterClass.load_static_actors("16_24")

	# Assert
	assert_gt(actors.size(), 0, "Chunk 16_24 deve carregar atores estaticos.")
	assert_true(actors[0].has("mesh_path"), "Ator deve conter mesh_path resolvido.")
	assert_true(actors[0].has("position"), "Ator deve conter position.")


func test_load_material_recipes() -> void:
	# Act
	var recipes = ChunkResourceAdapterClass.load_material_recipes("16_24")

	# Assert
	assert_gt(recipes.size(), 0, "Chunk 16_24 deve possuir receitas de materiais.")
	assert_true(
		recipes.has("speaking_tree_t.msleaf4"),
		"Deve conter a receita speaking_tree_t.msleaf4.",
	)
	var r = recipes["speaking_tree_t.msleaf4"]
	assert_true(r.has("diffuse_texture"), "Receita deve indicar diffuse_texture.")


func test_resolve_texture_path() -> void:
	# Act
	var resolved = ChunkResourceAdapterClass.resolve_texture_path(
		"res://assets/textures/speaking_tree_t/msleaf4.png"
	)
	var fallback_resolved = ChunkResourceAdapterClass.resolve_texture_path("msleaf4")

	# Assert
	assert_false(resolved.is_empty(), "Caminho de textura direta deve ser resolvido.")
	assert_true(resolved.ends_with(".png"), "Textura resolvida deve ser um arquivo png.")
	assert_false(
		fallback_resolved.is_empty(),
		"Busca por nome simples de textura deve ser resolvida.",
	)
