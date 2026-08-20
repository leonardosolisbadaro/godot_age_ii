## @file evaluate_chunk_water_presence_use_case.gd
## @path res://src/use_cases/evaluate_chunk_water_presence_use_case.gd
##
## @description
## Caso de uso para verificar e avaliar a presença de planos aquáticos ou submersão
## de entidades em um chunk a partir dos dados de zona de ambiente.
##
## @created 2026-08-19
## @updated 2026-08-20
##
## @author Leonardo S. Badaró
extends RefCounted

const EnvironmentZoneDataClass = preload("res://src/domain/environment_zone_data.gd")


func execute(world_pos: Vector3, env_data: EnvironmentZoneDataClass) -> Dictionary:
	if not env_data:
		return {
			"is_submerged": false,
			"depth": 0.0,
			"water_level": 0.0,
		}

	var is_sub = env_data.is_submerged_at(world_pos)
	var depth = env_data.get_water_depth_at(world_pos)
	var primary_level = 0.0

	for wv in env_data.water_volumes:
		if wv is Dictionary:
			primary_level = float(wv.get("water_z_meters", wv.get("water_plane_height_m", 0.0)))
			break

	return {
		"is_submerged": is_sub,
		"depth": depth,
		"water_level": primary_level,
	}
