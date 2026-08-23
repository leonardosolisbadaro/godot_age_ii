## @file predict_player_movement_use_case.gd
## @path res://src/core/use_cases/predict_player_movement_use_case.gd
##
## @description
## Caso de uso puro do Core Domain responsável por calcular deterministicamente
## o avanço cinemático do jogador (Client-Side Prediction) a 60Hz.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
class_name PredictPlayerMovementUseCase
extends RefCounted

const KinematicStateClass = preload("res://src/core/domain/kinematic_state.gd")
const MovementIntentClass = preload("res://src/core/domain/movement_intent.gd")
const PlayerStatsClass = preload("res://src/core/domain/player_stats.gd")


## Executa o cálculo determinístico do próximo estado cinemático.
static func execute(
	current_state: RefCounted,
	intent: RefCounted,
	stats: RefCounted,
	delta_time: float,
	altitude_sampler: RefCounted = null,
	terrain_chunk_data: RefCounted = null,
) -> RefCounted:
	if current_state == null:
		return KinematicStateClass.new()
	if intent == null or stats == null:
		return current_state.clone()

	var speed = stats.get_effective_run_speed_meters() if intent.is_running else stats.get_effective_walk_speed_meters()

	# Converte o input 2D local para a direção no mundo baseada no Yaw
	var local_dir = Vector3(intent.input_vector.x, 0.0, intent.input_vector.y)
	var world_dir = Vector3.ZERO
	if local_dir.length_squared() > 0.0001:
		world_dir = local_dir.normalized().rotated(Vector3.UP, intent.yaw_radians)

	var velocity = world_dir * speed
	var next_pos = current_state.position + velocity * delta_time

	# Ajuste de altitude do terreno se o amostrador e dados do chunk forem fornecidos
	var is_grounded = current_state.is_on_ground
	if altitude_sampler != null and terrain_chunk_data != null:
		if altitude_sampler.has_method("execute"):
			var ground_y = altitude_sampler.execute(terrain_chunk_data, next_pos)
			next_pos.y = ground_y
			is_grounded = true

	return KinematicStateClass.new(
		current_state.tick + 1,
		next_pos,
		velocity,
		intent.yaw_radians,
		is_grounded,
	)
