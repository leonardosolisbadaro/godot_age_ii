## @file test_movement_intent.gd
## @path res://tests/core/test_movement_intent.gd
##
## @description
## Testes unitarios GUT AAA da entidade MovementIntent e KinematicState.
## Valida estruturas de intencao de input desacopladas da engine.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
extends GutTest

const MovementIntentClass = preload("res://src/core/domain/movement_intent.gd")
const KinematicStateClass = preload("res://src/core/domain/kinematic_state.gd")


func test_movement_intent_defaults() -> void:
	# Arrange & Act
	var intent = MovementIntentClass.new()

	# Assert
	assert_eq(intent.input_vector, Vector2.ZERO, "Input vector inicial deve ser (0,0).")
	assert_true(intent.is_running, "Por padrao jogador corre.")
	assert_false(intent.is_jumping, "Por padrao jogador nao esta pulando.")
	assert_eq(intent.yaw_radians, 0.0, "Orientacao angular yaw inicial deve ser 0.0.")


func test_kinematic_state_clone_and_distance() -> void:
	# Arrange
	var state1 = KinematicStateClass.new(
		10,
		Vector3(100.0, 10.0, 200.0),
		Vector3(5.0, 0.0, 0.0),
		1.57,
		true,
	)

	# Act
	var clone = state1.clone()
	var state2 = KinematicStateClass.new(
		11,
		Vector3(103.0, 14.0, 200.0),
		Vector3(5.0, 0.0, 0.0),
		1.57,
		true,
	)
	var dist = state1.distance_to(state2)

	# Assert
	assert_eq(clone.tick, 10, "Clone deve ter o mesmo tick.")
	assert_eq(clone.position, Vector3(100.0, 10.0, 200.0), "Clone deve ter a mesma posicao.")
	assert_almost_eq(
		dist,
		5.0,
		0.001,
		"Distancia euclidiana 3D entre (100,10,200) e (103,14,200) deve ser 5.0m (sqrt(3^2 + 4^2)).",
	)
