## @file validate_player_movement_use_case.gd
## @path res://src/server/use_cases/validate_player_movement_use_case.gd
##
## @description
## Caso de uso puro do Servidor Autoritativo para validação cinemática de movimento.
## Aplica envelope dinâmico com tolerância elástica calibrada para telemetria de rede
## e checagem de altitude contra o terreno, acionando Snapback em caso de violação.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
class_name ValidatePlayerMovementUseCase
extends RefCounted

const KinematicStateClass = preload("res://src/core/domain/kinematic_state.gd")
const PlayerStatsClass = preload("res://src/core/domain/player_stats.gd")


## Executa a validação autoritativa do deslocamento submetido por um peer.
static func execute(
	last_confirmed_state: RefCounted,
	submitted_state: RefCounted,
	stats: RefCounted,
	delta_time: float,
	server_chunk_manager: RefCounted = null,
	elastic_tolerance: float = 0.20,
) -> Dictionary:
	if submitted_state == null:
		return { "valid": false, "reason": "NULL_STATE", "snapback_pos": Vector3.ZERO }

	if last_confirmed_state == null:
		return { "valid": true, "reason": "INITIAL_SPAWN", "state": submitted_state }

	var dt = clampf(delta_time, 0.001, 2.0)

	# 1. Validação de Limite de Velocidade Horizontal com Tolerância Elástica
	var max_run_speed = 9.6 # Fallback padrão em m/s
	if stats != null and stats.has_method("get_effective_run_speed_meters"):
		max_run_speed = stats.get_effective_run_speed_meters()

	# Envelope de velocidade: velocidade máx + tolerância elástica + folga contra jitter
	var max_allowed_speed = max_run_speed * (1.0 + elastic_tolerance) + 1.0
	var max_allowed_dist = max_allowed_speed * dt

	var last_p: Vector3 = last_confirmed_state.position
	var sub_p: Vector3 = submitted_state.position

	var horizontal_dist = Vector2(sub_p.x - last_p.x, sub_p.z - last_p.z).length()
	if horizontal_dist > max_allowed_dist:
		return {
			"valid": false,
			"reason": "SPEED_HACK",
			"snapback_pos": last_p,
		}

	# 2. Validação de Cota de Altitude contra o Relevo do Terreno
	if server_chunk_manager != null and server_chunk_manager.has_method("sample_altitude"):
		var ground_y = server_chunk_manager.sample_altitude(sub_p)
		var height_diff = sub_p.y - ground_y

		# Penetração abaixo do terreno
		if height_diff < -8.0:
			return {
				"valid": false,
				"reason": "UNDER_TERRAIN",
				"snapback_pos": Vector3(last_p.x, ground_y, last_p.z),
			}

		# Voo ou elevação não autorizada
		if height_diff > 25.0:
			return {
				"valid": false,
				"reason": "FLYING_HACK",
				"snapback_pos": Vector3(last_p.x, ground_y, last_p.z),
			}

	return {
		"valid": true,
		"reason": "OK",
		"state": submitted_state,
	}
