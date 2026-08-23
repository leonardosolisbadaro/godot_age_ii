## @file test_validate_player_movement_use_case.gd
## @path res://tests/server/test_validate_player_movement_use_case.gd
##
## @description
## Testes unitarios GUT AAA de ValidatePlayerMovementUseCase.
## Valida limites autoritativos de velocidade, tolerancia elastica contra jitter e rejeicao de anomalias.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
extends GutTest

const ValidatePlayerMovementUseCaseClass = preload(
	"res://src/server/use_cases/validate_player_movement_use_case.gd"
)
const KinematicStateClass = preload("res://src/core/domain/kinematic_state.gd")
const PlayerStatsClass = preload("res://src/core/domain/player_stats.gd")
const ServerChunkManagerClass = preload("res://src/server/infrastructure/server_chunk_manager.gd")


func test_valid_movement_within_tolerance() -> void:
	# Arrange
	var last_pos = Vector3(0.0, 10.0, 0.0)
	var last_state = KinematicStateClass.new(10, last_pos, Vector3.ZERO, 0.0, true)
	# Deslocamento legal: 8 metros em 1 segundo (velocidade max normal ~9.6 m/s)
	var new_pos = Vector3(0.0, 10.0, 8.0)
	var sub_state = KinematicStateClass.new(11, new_pos, Vector3(0.0, 0.0, 8.0), 0.0, true)
	var stats = PlayerStatsClass.new() # 120 UU/s = 9.6 m/s
	var delta = 1.0

	# Act
	var result = ValidatePlayerMovementUseCaseClass.execute(
		last_state,
		sub_state,
		stats,
		delta,
		null, # Sem chunk manager neste teste puro
		0.20,
	)

	# Assert
	assert_true(
		result["valid"],
		"Movimento de 8m/s deve ser considerado valido para corrida de 9.6m/s.",
	)
	assert_eq(result["reason"], "OK", "Motivo deve ser OK.")


func test_speedhack_rejection_triggers_snapback() -> void:
	# Arrange
	var last_pos = Vector3(0.0, 10.0, 0.0)
	var last_state = KinematicStateClass.new(10, last_pos, Vector3.ZERO, 0.0, true)
	# Deslocamento absurdo (Speedhack): 100 metros em 1 segundo
	var new_pos = Vector3(0.0, 10.0, 100.0)
	var sub_state = KinematicStateClass.new(11, new_pos, Vector3(0.0, 0.0, 100.0), 0.0, true)
	var stats = PlayerStatsClass.new()
	var delta = 1.0

	# Act
	var result = ValidatePlayerMovementUseCaseClass.execute(
		last_state,
		sub_state,
		stats,
		delta,
		null,
		0.20,
	)

	# Assert
	assert_false(result["valid"], "Deslocamento de 100m em 1s deve ser rejeitado.")
	assert_eq(result["reason"], "SPEED_HACK", "Motivo deve ser SPEED_HACK.")
	assert_eq(
		result["snapback_pos"],
		last_pos,
		"Snapback deve retornar a ultima posicao valida confirmada.",
	)
