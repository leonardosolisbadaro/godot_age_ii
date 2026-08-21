## @file test_radius_gizmo_node.gd
## @path res://tests/unit/infrastructure/test_radius_gizmo_node.gd
##
## @description
## Testes unitários AAA para o nó de visualização RadiusGizmoNode.
##
## @created 2026-08-21
## @updated 2026-08-21
##
## @author Leonardo S. Badaró
extends GutTest

const RadiusGizmoNodeClass = preload("res://src/infrastructure/radius_gizmo_node.gd")


func test_radius_gizmo_lifecycle_and_properties() -> void:
	# Arrange & Act
	var gizmo = RadiusGizmoNodeClass.new(40.0)

	# Assert
	assert_eq(gizmo.get_radius(), 40.0)
	assert_not_null(gizmo.get_node_or_null("GizmoMeshInstance"))

	# Act: Modifica raio
	gizmo.set_radius(65.0)
	assert_eq(gizmo.get_radius(), 65.0)

	# Act: Testa clamping mínimo e máximo
	gizmo.set_radius(2.0)
	assert_eq(gizmo.get_radius(), 5.0, "Raio mínimo deve ser 5.0m")

	gizmo.set_radius(150.0)
	assert_eq(gizmo.get_radius(), 100.0, "Raio máximo deve ser 100.0m")

	# Act: Alterna visibilidade
	gizmo.set_gizmo_visible(false)
	assert_false(gizmo.visible)

	gizmo.set_gizmo_visible(true)
	assert_true(gizmo.visible)

	# Cleanup
	gizmo.free()
