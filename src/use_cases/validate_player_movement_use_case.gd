## @file validate_player_movement_use_case.gd
## @path res://src/use_cases/validate_player_movement_use_case.gd
##
## @description
## Caso de uso para validação autoritativa de movimentação e física do jogador,
## integrando amostragem de terreno multi-chunk e prevenção de speedhack/teleporte.
##
## @created 2026-08-19
## @updated 2026-08-20
##
## @author Leonardo S. Badaró
extends RefCounted

const ServerMovementValidatorClass = preload("res://src/domain/server_movement_validator.gd")


func execute(
	from_pos: Vector3,
	to_pos: Vector3,
	chunks_data: Dictionary,
	samplers: Dictionary,
	obstacle_indices: Dictionary = { },
	delta_time: float = ServerMovementValidatorClass.DEFAULT_DELTA_TIME,
	max_speed: float = ServerMovementValidatorClass.DEFAULT_MAX_SPEED,
	max_slope_ratio: float = ServerMovementValidatorClass.DEFAULT_MAX_SLOPE_RATIO,
	entity_radius: float = ServerMovementValidatorClass.DEFAULT_ENTITY_RADIUS,
) -> Dictionary:
	var validator = ServerMovementValidatorClass.new()

	# Identifica o sampler e índice de obstáculos do chunk ativo de destino
	var active_sampler = null
	var active_obstacle_index = null
	for c_name in chunks_data.keys():
		var chunk = chunks_data[c_name]
		if (
			chunk and chunk.has_method("contains_world_point")
			and chunk.contains_world_point(to_pos.x, to_pos.z)
		):
			active_sampler = samplers.get(c_name, null)
			active_obstacle_index = obstacle_indices.get(c_name, null)
			break

	return validator.validate_step(
		from_pos,
		to_pos,
		active_sampler,
		null,
		active_obstacle_index,
		delta_time,
		max_speed,
		max_slope_ratio,
		ServerMovementValidatorClass.DEFAULT_TOLERANCE_FACTOR,
		entity_radius,
	)
