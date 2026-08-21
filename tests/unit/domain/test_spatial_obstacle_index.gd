## @file test_spatial_obstacle_index.gd
## @path res://tests/unit/domain/test_spatial_obstacle_index.gd
##
## @description
## Testes unitários AAA para o índice espacial analítico SpatialObstacleIndex.
##
## @created 2026-08-21
## @updated 2026-08-21
##
## @author Leonardo S. Badaró
extends GutTest

const SpatialObstacleIndexClass = preload("res://src/domain/spatial_obstacle_index.gd")
const SpatialStaticObstacleClass = preload("res://src/domain/spatial_static_obstacle.gd")


func test_spatial_index_partitioning_and_collision() -> void:
	# Arrange: Grade espacial para o chunk 17_25
	var index = SpatialObstacleIndexClass.new("17_25", 16.0)

	var tree1 = SpatialStaticObstacleClass.create_cylinder(
		"tree_01",
		Vector2(100.0, 100.0),
		0.6,
		-100.0,
		100.0
	)
	var rock1 = SpatialStaticObstacleClass.create_box(
		"rock_01",
		Vector3(200.0, 0.0, 200.0),
		Vector3(205.0, 4.0, 205.0)
	)

	# Act: Inserção no índice
	index.add_obstacle(tree1)
	index.add_obstacle(rock1)

	# Assert 1: Quantidade total
	assert_eq(index.get_obstacle_count(), 2)

	# Assert 2: Teste de ponto colidindo com a árvore em (100, 100)
	assert_true(index.is_position_blocked(Vector3(100.0, 1.0, 100.0), 0.4), "Deve detectar colisão na árvore")

	# Assert 3: Teste de ponto livre em (150, 150)
	assert_false(index.is_position_blocked(Vector3(150.0, 1.0, 150.0), 0.4), "Ponto vazio não deve colidir")

	# Assert 4: Segmento atravessando a rocha de (198, 202) para (207, 202)
	assert_true(
		index.is_segment_blocked(Vector3(198.0, 1.0, 202.0), Vector3(207.0, 1.0, 202.0), 0.4),
		"Passo cruzando a rocha deve ser bloqueado"
	)

	# Assert 5: Segmento seguro em (150, 150) -> (160, 150)
	assert_false(
		index.is_segment_blocked(Vector3(150.0, 1.0, 150.0), Vector3(160.0, 1.0, 150.0), 0.4),
		"Passo seguro não deve ser bloqueado"
	)
