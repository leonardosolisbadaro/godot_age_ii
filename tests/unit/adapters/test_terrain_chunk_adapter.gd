## @file test_terrain_chunk_adapter.gd
## @path res://tests/unit/adapters/test_terrain_chunk_adapter.gd
##
## @description
## Testes unitários AAA para TerrainChunkAdapter.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends GutTest

const TerrainChunkAdapterClass = preload("res://src/adapters/terrain_chunk_adapter.gd")


func test_get_visual_glb_path() -> void:
	# Arrange
	var adapter = TerrainChunkAdapterClass.new()

	# Act
	var path = adapter.get_visual_glb_path("16_24", "res://assets/maps")

	# Assert
	assert_eq(path, "res://assets/maps/16_24/client/16_24_visual.glb")


func test_load_visual_mesh_node_real_chunk() -> void:
	# Arrange
	var adapter = TerrainChunkAdapterClass.new()

	# Act
	var node = adapter.load_visual_mesh_node("16_24", "res://assets/maps")

	# Assert
	assert_not_null(node, "Cena compilada de 16_24_visual.glb deve ser carregada")

	# Cleanup
	if node:
		node.free()
