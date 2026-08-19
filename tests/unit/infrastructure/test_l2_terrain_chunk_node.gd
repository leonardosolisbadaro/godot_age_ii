## @file test_l2_terrain_chunk_node.gd
## @path res://tests/unit/infrastructure/test_l2_terrain_chunk_node.gd
##
## @description
## Testes unitários AAA para o nó de infraestrutura L2TerrainChunkNode.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends GutTest

const L2TerrainChunkNodeClass = preload("res://src/infrastructure/l2_terrain_chunk_node.gd")


func test_l2_terrain_chunk_node_instantiation() -> void:
	# Arrange
	var node = L2TerrainChunkNodeClass.new("16_24", "res://assets/maps")

	# Act
	node.build_chunk_node()

	# Assert
	assert_eq(node.chunk_name, "16_24")
	assert_gt(node.get_child_count(), 0, "Deve conter instâncias visuais e colisão física")

	# Cleanup
	node.free()
