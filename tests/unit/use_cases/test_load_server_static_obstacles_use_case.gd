## @file test_load_server_static_obstacles_use_case.gd
## @path res://tests/unit/use_cases/test_load_server_static_obstacles_use_case.gd
##
## @description
## Testes unitários AAA para o caso de uso LoadServerStaticObstaclesUseCase.
##
## @created 2026-08-21
## @updated 2026-08-21
##
## @author Leonardo S. Badaró
extends GutTest

const LoadServerStaticObstaclesUseCaseClass = preload("res://src/use_cases/load_server_static_obstacles_use_case.gd")


func test_load_server_static_obstacles_chunk_17_25() -> void:
	# Arrange
	var use_case = LoadServerStaticObstaclesUseCaseClass.new()

	# Act
	var index = use_case.execute("17_25", "res://assets/maps")

	# Assert
	assert_not_null(index, "Deve instanciar SpatialObstacleIndex")
	assert_gt(index.get_obstacle_count(), 0, "Chunk 17_25 deve conter centenas de obstáculos estáticos indexados")


func test_load_server_static_obstacles_invalid_chunk_returns_empty_index() -> void:
	# Arrange
	var use_case = LoadServerStaticObstaclesUseCaseClass.new()

	# Act
	var index = use_case.execute("99_99", "res://assets/maps")

	# Assert
	assert_not_null(index)
	assert_eq(index.get_obstacle_count(), 0, "Chunk inexistente deve retornar índice com 0 obstáculos")
