## @file test_world_chunk_manager.gd
## @path res://tests/unit/infrastructure/test_world_chunk_manager.gd
##
## @description
## Testes unitários AAA para o nó de infraestrutura WorldChunkManager.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends GutTest

const WorldChunkManagerClass = preload("res://src/infrastructure/world_chunk_manager.gd")


func test_register_and_stream_chunk() -> void:
	# Arrange
	var manager = WorldChunkManagerClass.new("res://assets/maps", 1500.0)

	# Act
	var registered = manager.register_chunk("16_24")
	assert_true(registered, "Chunk 16_24 deve ser registrado com sucesso")

	# Simula avatar próximo do chunk 16_24
	manager.update_streaming(Vector3(-6552.0, -100.0, 19659.0))

	# Assert
	assert_eq(manager.get_active_chunk_count(), 1, "Chunk 16_24 deve estar carregado e ativo")

	# Act: Avatar move para longe
	manager.update_streaming(Vector3(50000.0, 0.0, 50000.0))

	# Assert
	assert_eq(manager.get_active_chunk_count(), 0, "Chunk 16_24 deve ter sido descarregado")

	# Cleanup
	manager.free()
