## @file test_predict_player_movement_use_case.gd
## @path res://tests/core/test_predict_player_movement_use_case.gd
##
## @description
## Testes unitarios GUT AAA de PredictPlayerMovementUseCase.
## Valida avanco cinematico deterministico local do avatar a 60Hz.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
extends GutTest

const PredictPlayerMovementUseCaseClass = preload(
	"res://src/core/use_cases/predict_player_movement_use_case.gd"
)
const KinematicStateClass = preload("res://src/core/domain/kinematic_state.gd")
const MovementIntentClass = preload("res://src/core/domain/movement_intent.gd")
const PlayerStatsClass = preload("res://src/core/domain/player_stats.gd")


func test_predict_movement_stationary() -> void:
	# Arrange
	var initial_state = KinematicStateClass.new(0, Vector3(0.0, 10.0, 0.0), Vector3.ZERO, 0.0, true)
	var intent = MovementIntentClass.new(Vector2.ZERO, true, false, 0.0)
	var stats = PlayerStatsClass.new()
	var delta = 1.0 / 60.0

	# Act
	var next_state = PredictPlayerMovementUseCaseClass.execute(initial_state, intent, stats, delta)

	# Assert
	assert_eq(next_state.tick, 1, "Tick deve avancar em 1.")
	assert_eq(next_state.position, Vector3(0.0, 10.0, 0.0), "Posicao nao deve mudar sem input.")
	assert_eq(next_state.velocity, Vector3.ZERO, "Velocidade deve ser zero.")


func test_predict_movement_forward() -> void:
	# Arrange
	var initial_state = KinematicStateClass.new(10, Vector3(0.0, 0.0, 0.0), Vector3.ZERO, 0.0, true)
	# Input Y=-1.0 significa frente no espaco local (-Z)
	var intent = MovementIntentClass.new(Vector2(0.0, -1.0), true, false, 0.0)
	var stats = PlayerStatsClass.new() # 120 UU/s * 0.08 = 9.6 m/s
	var delta = 1.0 # 1 segundo completo para validacao direta

	# Act
	var next_state = PredictPlayerMovementUseCaseClass.execute(initial_state, intent, stats, delta)

	# Assert
	assert_eq(next_state.tick, 11, "Tick deve ser 11.")
	assert_almost_eq(
		next_state.position.z,
		-9.6,
		0.01,
		"Posicao Z deve ser -9.6m (9.6 m/s * 1.0s para frente).",
	)
	assert_almost_eq(next_state.position.x, 0.0, 0.01, "Posicao X deve continuar 0.0m.")
