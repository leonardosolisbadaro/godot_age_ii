## @file test_ocean_plane_node.gd
## @path res://tests/unit/infrastructure/test_ocean_plane_node.gd
##
## @description
## Testes unitários AAA para o nó de infraestrutura OceanPlaneNode.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends GutTest

const OceanPlaneNodeClass = preload("res://src/infrastructure/ocean_plane_node.gd")


func test_ocean_plane_node_instantiation() -> void:
	# Arrange
	var node = OceanPlaneNodeClass.new(-5.0, Vector2(1000.0, 1000.0))

	# Act
	node.build_ocean_plane()

	# Assert
	assert_not_null(node.mesh)
	assert_almost_eq(node.position.y, -5.0, 0.001)
	assert_not_null(node.material_override)

	# Cleanup
	node.free()
