## @file evaluate_chunk_water_presence_use_case.gd
## @path res://src/use_cases/evaluate_chunk_water_presence_use_case.gd
##
## @description
## Caso de uso para avaliar se uma posição no mundo 3D está submersa em corpos d'água
## ou oceanos, calculando a profundidade do fluido para transição de estados de natação.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends RefCounted


func execute(world_pos: Vector3, env_zone_data: RefCounted) -> Dictionary:
	var result = {
		"is_submerged": false,
		"depth": 0.0,
		"water_level": 0.0
	}

	if not env_zone_data:
		return result

	if env_zone_data.has_method("is_submerged_at"):
		result["is_submerged"] = env_zone_data.is_submerged_at(world_pos)
		result["depth"] = env_zone_data.get_water_depth_at(world_pos)
		if result["is_submerged"]:
			result["water_level"] = world_pos.y + result["depth"]

	return result
