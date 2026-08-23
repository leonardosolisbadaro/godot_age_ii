## @file test_terrain_hole_mask.gd
## @path res://tests/core/test_terrain_hole_mask.gd
##
## @description
## Testes unitarios GUT AAA do TerrainHoleMask.
## Valida definicao e consulta de buracos no terreno e contagem total.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
extends GutTest

const TerrainHoleMaskClass = preload("res://src/core/domain/terrain_hole_mask.gd")


func test_hole_mask_operations() -> void:
	# Arrange
	var mask = TerrainHoleMaskClass.new(128)

	# Act - Adiciona buraco em (10, 20)
	mask.set_hole(10, 20, true)

	# Assert
	assert_true(mask.is_hole(10, 20), "Quad (10, 20) deve ser identificado como buraco.")
	assert_false(mask.is_hole(10, 21), "Quad vizinho nao deve ser buraco.")
	assert_eq(mask.get_hole_count(), 1, "Total de buracos deve ser 1.")

	# Act - Remove o buraco
	mask.set_hole(10, 20, false)

	# Assert
	assert_false(mask.is_hole(10, 20), "Quad (10, 20) nao deve mais ser buraco apos remocao.")
	assert_eq(mask.get_hole_count(), 0, "Total de buracos deve ser 0.")
