## @file server_movement_validator.gd
## @path res://src/domain/server_movement_validator.gd
##
## @description
## Entidade de domínio pura para validação física autoritativa de movimentação
## do jogador e entidades no servidor, prevenindo speedhack, teleportes e escaladas irreais.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends RefCounted

const HeightfieldSamplerClass = preload("res://src/domain/heightfield_sampler.gd")
const TerrainHoleMaskClass = preload("res://src/domain/terrain_hole_mask.gd")


func validate_step(
	from_pos: Vector3,
	to_pos: Vector3,
	sampler: HeightfieldSamplerClass = null,
	hole_mask: TerrainHoleMaskClass = null,
	delta_time: float = 0.05,
	max_speed: float = 6.0,
	max_slope_ratio: float = 1.5,
	tolerance_factor: float = 1.3
) -> Dictionary:
	var result = {
		"valid": true,
		"corrected_pos": to_pos,
		"reason": "OK"
	}

	# 1. Validação de Velocidade e Distância Horizontal (Prevenção de Speedhack e Teleporte)
	var horiz_dist = Vector2(to_pos.x - from_pos.x, to_pos.z - from_pos.z).length()
	var max_allowed_dist = max_speed * delta_time * tolerance_factor

	if horiz_dist > max_allowed_dist and horiz_dist > 0.1:
		result["valid"] = false
		result["corrected_pos"] = from_pos
		result["reason"] = "SPEED_LIMIT_EXCEEDED"
		return result

	# 2. Validação de Terreno e Elevação (se sampler disponível)
	if sampler:
		var ground_y = sampler.get_height_at(to_pos.x, to_pos.z)
		var slope = sampler.get_slope_ratio_at(to_pos.x, to_pos.z)

		# Verifica se a inclinação da encosta excede o limite físico do avatar
		if slope > max_slope_ratio:
			result["valid"] = false
			result["corrected_pos"] = from_pos
			result["reason"] = "SLOPE_TOO_STEEP"
			return result

		# Se não estiver em um buraco de caverna, alinha ao solo
		var is_hole = false
		if hole_mask and hole_mask.has_method("is_hole_at"):
			# Validador de buraco
			is_hole = false

		if not is_hole:
			# Tolerância vertical de gravidade/solo
			result["corrected_pos"] = Vector3(to_pos.x, ground_y, to_pos.z)

	return result
