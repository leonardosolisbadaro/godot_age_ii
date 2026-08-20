## @file test_mesh_selection_highlighter.gd
## @path res://tests/unit/infrastructure/test_mesh_selection_highlighter.gd
##
## @description
## Testes unitários AAA para o nó de highlight de seleção MeshSelectionHighlighter.
##
## @created 2026-08-20
## @updated 2026-08-20
##
## @author Leonardo S. Badaró
extends GutTest

const MeshSelectionHighlighterClass = preload("res://src/infrastructure/mesh_selection_highlighter.gd")


func test_mesh_selection_highlighter_lifecycle() -> void:
	# Arrange
	var highlighter = MeshSelectionHighlighterClass.new()
	var test_aabb = AABB(Vector3(-10.0, 0.0, -10.0), Vector3(20.0, 10.0, 20.0))
	var box_mesh = BoxMesh.new()

	# Act & Assert 1: Inicialmente invisível
	assert_false(highlighter.visible, "Highlighter deve iniciar invisível")

	# Act 2: Aplica AABB
	highlighter.highlight_aabb(test_aabb)

	# Assert 2: Fica visível ao receber AABB válido
	assert_true(highlighter.visible, "Highlighter deve ficar visível após highlight_aabb")

	# Act 3: Aplica Mesh e AABB
	highlighter.highlight_mesh_and_aabb(box_mesh, Transform3D.IDENTITY, test_aabb)
	assert_true(highlighter.visible, "Highlighter deve ficar visível com malha")

	# Act 4: Limpa highlight
	highlighter.clear_highlight()

	# Assert 4: Fica invisível após clear_highlight
	assert_false(highlighter.visible, "Highlighter deve ficar invisível após clear_highlight")

	# Cleanup
	highlighter.free()
