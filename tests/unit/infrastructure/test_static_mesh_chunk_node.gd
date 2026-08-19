## @file test_static_mesh_chunk_node.gd
## @path res://tests/unit/infrastructure/test_static_mesh_chunk_node.gd
##
## @description
## Testes unitários AAA para o nó de infraestrutura StaticMeshChunkNode.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends GutTest

const StaticMeshChunkNodeClass = preload("res://src/infrastructure/static_mesh_chunk_node.gd")


func test_static_mesh_chunk_node_instantiation() -> void:
	# Arrange
	var node = StaticMeshChunkNodeClass.new("16_24", "res://assets/maps")

	# Act
	node.build_static_meshes()

	# Assert
	assert_eq(node.chunk_name, "16_24")
	assert_gt(node.get_multimesh_count(), 0, "Deve conter instâncias de MultiMesh agrupadas")

	# Cleanup
	node.free()
