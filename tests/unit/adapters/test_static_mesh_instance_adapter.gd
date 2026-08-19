## @file test_static_mesh_instance_adapter.gd
## @path res://tests/unit/adapters/test_static_mesh_instance_adapter.gd
##
## @description
## Testes unitários AAA para StaticMeshInstanceAdapter.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends GutTest

const StaticMeshInstanceAdapterClass = preload("res://src/adapters/static_mesh_instance_adapter.gd")
const StaticMeshInstanceDataClass = preload("res://src/domain/static_mesh_instance_data.gd")


func test_parse_and_group_by_mesh() -> void:
	# Arrange
	var raw_actors = [
		{
			"actor_name": "Fence01",
			"mesh_name": "fence",
			"mesh_resource_path": "res://assets/models/fence.glb",
			"position_meters": [10.0, 0.0, 10.0],
			"rotation_radians": [0.0, 0.0, 0.0],
			"scale": [1.0, 1.0, 1.0]
		},
		{
			"actor_name": "Fence02",
			"mesh_name": "fence",
			"mesh_resource_path": "res://assets/models/fence.glb",
			"position_meters": [20.0, 0.0, 10.0],
			"rotation_radians": [0.0, 1.57, 0.0],
			"scale": [1.0, 1.0, 1.0]
		},
		{
			"actor_name": "Tree01",
			"mesh_name": "tree",
			"mesh_resource_path": "res://assets/models/tree.glb",
			"position_meters": [50.0, 0.0, 50.0],
			"rotation_radians": [0.0, 0.0, 0.0],
			"scale": [1.5, 1.5, 1.5]
		}
	]

	var adapter = StaticMeshInstanceAdapterClass.new()

	# Act
	var parsed = adapter.parse_actor_dictionaries(raw_actors)
	var groups = adapter.group_by_mesh_path(parsed)

	# Assert
	assert_eq(parsed.size(), 3)
	assert_eq(groups.keys().size(), 2)
	assert_eq(groups["res://assets/models/fence.glb"].size(), 2)
	assert_eq(groups["res://assets/models/tree.glb"].size(), 1)


func test_create_multimesh_instance() -> void:
	# Arrange
	var adapter = StaticMeshInstanceAdapterClass.new()
	var box_mesh = BoxMesh.new()
	var inst1 = StaticMeshInstanceDataClass.new("Box1", "box", "res://box.glb", Vector3(10, 0, 10))
	var inst2 = StaticMeshInstanceDataClass.new("Box2", "box", "res://box.glb", Vector3(20, 0, 20))

	# Act
	var mm_node = adapter.create_multimesh_instance(box_mesh, [inst1, inst2])

	# Assert
	assert_not_null(mm_node)
	assert_eq(mm_node.multimesh.instance_count, 2)
	assert_eq(mm_node.multimesh.transform_format, MultiMesh.TRANSFORM_3D)
	assert_eq(mm_node.multimesh.mesh, box_mesh)

	# Cleanup
	mm_node.free()
