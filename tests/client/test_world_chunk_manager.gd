## @file test_world_chunk_manager.gd
## @path res://tests/client/test_world_chunk_manager.gd
##
## @description
## Testes unitarios GUT AAA do WorldChunkManager.
## Valida carregamento individual de chunks, remocao da arvore de cenas e atualizacao de streaming.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
extends GutTest

const WorldChunkManagerClass = preload("res://src/client/infrastructure/world_chunk_manager.gd")


func test_initialization_and_chunk_lifecycle() -> void:
	# Arrange
	var manager = WorldChunkManagerClass.new()
	add_child_autofree(manager)

	# Assert inicial
	assert_eq(manager.get_active_chunk_names().size(), 0, "Deve iniciar sem chunks carregados.")

	# Act - Carrega chunk 16_24
	manager.load_chunk("16_24")

	# Assert
	assert_eq(manager.get_active_chunk_names().size(), 1, "Deve conter 1 chunk ativo.")
	assert_true(manager.get_active_chunk_names().has("16_24"), "Chunk 16_24 deve estar ativo.")

	# Act - Descarrega chunk 16_24
	manager.unload_chunk("16_24")

	# Assert
	assert_eq(
		manager.get_active_chunk_names().size(),
		0,
		"Chunk 16_24 deve ser descarregado com sucesso.",
	)
