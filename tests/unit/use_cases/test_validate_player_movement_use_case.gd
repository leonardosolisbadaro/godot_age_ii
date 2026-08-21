## @file test_validate_player_movement_use_case.gd
## @path res://tests/unit/use_cases/test_validate_player_movement_use_case.gd
##
## @description
## Testes unitários AAA para ValidatePlayerMovementUseCase.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends GutTest

const ValidatePlayerMovementUseCaseClass = preload("res://src/use_cases/validate_player_movement_use_case.gd")
const TerrainChunkDataClass = preload("res://src/domain/terrain_chunk_data.gd")
const HeightfieldSamplerClass = preload("res://src/domain/heightfield_sampler.gd")


func test_validate_player_movement_valid_step() -> void:
	# Arrange: Terreno plano em Y = 20.0
	var chunk = TerrainChunkDataClass.new("16_24", 16, 24, Vector3.ZERO, 100.0, 100.0)
	var sampler = HeightfieldSamplerClass.new(
		PackedFloat32Array([20.0, 20.0, 20.0, 20.0]),
		2, 2, 100.0, 100.0, Vector3.ZERO, 100.0, 100.0
	)
	var chunks = { "16_24": chunk }
	var samplers = { "16_24": sampler }

	var use_case = ValidatePlayerMovementUseCaseClass.new()

	# Act: Jogador caminha de (0, 20, 0) para (0.2, 20, 0.1)
	var res = use_case.execute(
		Vector3(0.0, 20.0, 0.0),
		Vector3(0.2, 20.0, 0.1),
		chunks,
		samplers,
		{ },
		0.05,
		6.0
	)

	# Assert
	assert_true(res["valid"])
	assert_eq(res["reason"], "OK")
	assert_almost_eq(res["corrected_pos"], Vector3(0.2, 20.0, 0.1), Vector3(0.001, 0.001, 0.001))


func test_validate_player_movement_obstacle_rejection() -> void:
	# Arrange
	var SpatialObstacleIndexClass = preload("res://src/domain/spatial_obstacle_index.gd")
	var SpatialStaticObstacleClass = preload("res://src/domain/spatial_static_obstacle.gd")

	var chunk = TerrainChunkDataClass.new("16_24", 16, 24, Vector3.ZERO, 100.0, 100.0)
	var sampler = HeightfieldSamplerClass.new(
		PackedFloat32Array([20.0, 20.0, 20.0, 20.0]),
		2, 2, 100.0, 100.0, Vector3.ZERO, 100.0, 100.0
	)
	var index = SpatialObstacleIndexClass.new("16_24", 16.0)
	var tree = SpatialStaticObstacleClass.create_cylinder("tree_01", Vector2(0.3, 0.0), 0.5, 0.0, 40.0)
	index.add_obstacle(tree)

	var chunks = { "16_24": chunk }
	var samplers = { "16_24": sampler }
	var obstacles = { "16_24": index }

	var use_case = ValidatePlayerMovementUseCaseClass.new()

	# Act: Jogador tenta dar um passo curto de 0.25m entrando no tronco da árvore
	var res = use_case.execute(
		Vector3(0.0, 20.0, 0.0),
		Vector3(0.25, 20.0, 0.0),
		chunks,
		samplers,
		obstacles,
		0.05,
		6.0
	)

	# Assert
	assert_false(res["valid"], "Movimento atravessando árvore deve ser bloqueado")
	assert_eq(res["reason"], "OBSTACLE_COLLISION")
