## @file test_static_mesh_instance_data.gd
## @path res://tests/core/test_static_mesh_instance_data.gd
##
## @description
## Testes unitarios GUT AAA do StaticMeshInstanceData.
## Valida propriedades imutaveis, extracao de posicao e escala da Transform3D.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
extends GutTest

const StaticMeshInstanceDataClass = preload("res://src/core/domain/static_mesh_instance_data.gd")


func test_instance_data_properties() -> void:
	# Arrange
	var sample_transform = Transform3D().scaled(Vector3(2.0, 2.0, 2.0)).translated(
		Vector3(15.0, 10.0, -25.0)
	)

	# Act
	var instance = StaticMeshInstanceDataClass.new(
		"Tree01_m",
		sample_transform,
		true,
		true,
		false,
	)

	# Assert
	assert_eq(instance.mesh_name, "Tree01_m", "Nome da malha deve ser Tree01_m.")
	assert_eq(
		instance.get_position(),
		Vector3(15.0, 10.0, -25.0),
		"Posicao extraida deve ser exata.",
	)
	assert_almost_eq(instance.get_scale().x, 2.0, 0.001, "Escala X deve ser 2.0.")
	assert_true(instance.collision_enabled, "Colisao deve estar ativada.")
	assert_true(instance.two_sided, "Two-sided deve estar ativado.")
	assert_false(instance.alpha_scissor, "Alpha-scissor deve estar desativado.")
