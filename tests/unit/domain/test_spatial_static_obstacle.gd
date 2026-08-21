## @file test_spatial_static_obstacle.gd
## @path res://tests/unit/domain/test_spatial_static_obstacle.gd
##
## @description
## Testes unitários AAA para a entidade analítica de domínio SpatialStaticObstacle.
##
## @created 2026-08-21
## @updated 2026-08-21
##
## @author Leonardo S. Badaró
extends GutTest

const SpatialStaticObstacleClass = preload("res://src/domain/spatial_static_obstacle.gd")


func test_cylinder_trunk_collision() -> void:
	# Arrange: Tronco de árvore centrado em (10, 20), raio 0.5m, altura Y de 0 a 10m
	var trunk = SpatialStaticObstacleClass.create_cylinder(
		"tree_01",
		Vector2(10.0, 20.0),
		0.5,
		0.0,
		10.0
	)

	# Act & Assert 1: Ponto exatamente no centro do tronco
	assert_true(trunk.intersects_point_2d(10.0, 20.0, 0.4, 2.0), "Ponto dentro do raio deve colidir")

	# Act & Assert 2: Ponto longe do tronco (15, 20)
	assert_false(trunk.intersects_point_2d(15.0, 20.0, 0.4, 2.0), "Ponto a 5m de distância não deve colidir")

	# Act & Assert 3: Ponto acima da altura máxima do tronco (Y = 15m)
	assert_false(trunk.intersects_point_2d(10.0, 20.0, 0.4, 15.0), "Ponto acima do topo da árvore não deve colidir")

	# Act & Assert 4: Segmento de movimento atravessando o tronco (de (8, 20) para (12, 20))
	var from_p = Vector3(8.0, 1.0, 20.0)
	var to_p = Vector3(12.0, 1.0, 20.0)
	assert_true(trunk.intersects_segment_3d(from_p, to_p, 0.4), "Segmento que cruza o tronco deve ser detectado")

	# Act & Assert 5: Segmento de movimento passando ao lado (de (8, 25) para (12, 25))
	var safe_from = Vector3(8.0, 1.0, 25.0)
	var safe_to = Vector3(12.0, 1.0, 25.0)
	assert_false(trunk.intersects_segment_3d(safe_from, safe_to, 0.4), "Segmento seguro não deve colidir")


func test_box_obstacle_collision() -> void:
	# Arrange: Rocha/Caixa AABB de [0, 0, 0] até [4, 3, 4]
	var box = SpatialStaticObstacleClass.create_box(
		"rock_01",
		Vector3(0.0, 0.0, 0.0),
		Vector3(4.0, 3.0, 4.0)
	)

	# Act & Assert: Ponto dentro da caixa
	assert_true(box.intersects_point_2d(2.0, 2.0, 0.0, 1.5), "Centro da caixa deve colidir")

	# Act & Assert: Segmento atravessando a caixa de (-2, 2, 2) até (6, 2, 2)
	assert_true(box.intersects_segment_3d(Vector3(-2.0, 1.0, 2.0), Vector3(6.0, 1.0, 2.0), 0.2))

	# Act & Assert: Segmento fora da caixa
	assert_false(box.intersects_segment_3d(Vector3(-2.0, 1.0, 10.0), Vector3(6.0, 1.0, 10.0), 0.2))
