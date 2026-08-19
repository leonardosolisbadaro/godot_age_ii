## @file test_static_mesh_instance_data.gd
## @path res://tests/unit/domain/test_static_mesh_instance_data.gd
##
## @description
## Testes unitários AAA para a entidade de domínio StaticMeshInstanceData.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends GutTest

const StaticMeshInstanceDataClass = preload("res://src/domain/static_mesh_instance_data.gd")


func test_instantiation_and_from_dictionary() -> void:
	# Arrange
	var data = StaticMeshInstanceDataClass.new()
	var actor_dict = {
		"actor_name": "StaticMeshActor35",
		"mesh_name": "woodfence",
		"mesh_resource_path": "res://assets/models/field_deco_t/woodfence.glb",
		"position_meters": [-6500.0, -120.0, 19500.0],
		"rotation_radians": [0.0, 1.5708, 0.0],
		"scale": [1.0, 1.0, 1.0],
		"base_aabb": {
			"position": [-2.0, 0.0, -0.5],
			"size": [4.0, 1.5, 1.0]
		}
	}

	# Act
	data.from_actor_dictionary(actor_dict)

	# Assert
	assert_eq(data.actor_name, "StaticMeshActor35")
	assert_eq(data.mesh_name, "woodfence")
	assert_eq(data.position, Vector3(-6500.0, -120.0, 19500.0))
	assert_almost_eq(data.rotation_radians.y, 1.5708, 0.001)
	assert_eq(data.scale, Vector3.ONE)


func test_world_aabb_and_point_intersection() -> void:
	# Arrange: Objeto posicionado em (10, 0, 10) com base AABB [-1..1, 0..2, -1..1] e escala 2x
	var data = StaticMeshInstanceDataClass.new(
		"stone_pillar",
		"pillar",
		"res://assets/models/pillar.glb",
		Vector3(10.0, 0.0, 10.0),
		Vector3.ZERO,
		Vector3(2.0, 2.0, 2.0),
		AABB(Vector3(-1.0, 0.0, -1.0), Vector3(2.0, 2.0, 2.0))
	)

	# Act
	var world_aabb = data.get_world_aabb()

	# Assert
	assert_almost_eq(world_aabb.position, Vector3(8.0, 0.0, 8.0), Vector3(0.001, 0.001, 0.001))
	assert_almost_eq(world_aabb.size, Vector3(4.0, 4.0, 4.0), Vector3(0.001, 0.001, 0.001))

	assert_true(data.intersects_point(Vector3(10.0, 2.0, 10.0)), "Centro do objeto deve estar contido")
	assert_false(data.intersects_point(Vector3(5.0, 2.0, 10.0)), "Ponto fora do X deve retornar falso")
	assert_false(data.intersects_point(Vector3(10.0, 10.0, 10.0)), "Ponto acima do topo deve retornar falso")


func test_get_transform() -> void:
	# Arrange
	var data = StaticMeshInstanceDataClass.new(
		"tree_01",
		"tree",
		"res://assets/models/tree.glb",
		Vector3(100.0, 50.0, -200.0),
		Vector3.ZERO,
		Vector3(1.5, 1.5, 1.5)
	)

	# Act
	var t = data.get_transform()

	# Assert
	assert_almost_eq(t.origin, Vector3(100.0, 50.0, -200.0), Vector3(0.001, 0.001, 0.001))
	assert_almost_eq(t.basis.get_scale(), Vector3(1.5, 1.5, 1.5), Vector3(0.001, 0.001, 0.001))
