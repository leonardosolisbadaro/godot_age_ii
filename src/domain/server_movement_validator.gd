## @file server_movement_validator.gd
## @path res://src/domain/server_movement_validator.gd
##
## @description
## Entidade de domínio pura para validação física autoritativa de movimentação
## do jogador e entidades no servidor, prevenindo speedhack, teleportes e escaladas irreais.
##
## @created 2026-08-19
## @updated 2026-08-20
##
## @author Leonardo S. Badaró
extends RefCounted

const HeightfieldSamplerClass = preload("res://src/domain/heightfield_sampler.gd")
const TerrainHoleMaskClass = preload("res://src/domain/terrain_hole_mask.gd")

# ==============================================================================
# CONSTANTES SEMÂNTICAS DE VALIDAÇÃO DE MOVIMENTO
# ==============================================================================

## @const DEFAULT_DELTA_TIME (float)
## O que: Intervalo de tempo padrão de física entre ticks de validação no servidor (0.05s = 20Hz).
## Porque: Frequência padrão de simulação de entidades de rede.
const DEFAULT_DELTA_TIME: float = 0.05

## @const DEFAULT_MAX_SPEED (float)
## O que: Velocidade máxima padrão permitida em metros por segundo (6.0 m/s).
## Porque: Velocidade canônica de corrida para humanoides em Lineage II.
const DEFAULT_MAX_SPEED: float = 6.0

## @const DEFAULT_MAX_SLOPE_RATIO (float)
## O que: Proporção máxima de inclinação de rampa permitida para caminhada (1.5 = ~56 graus).
## Porque: Encostas mais íngremes que este limite são intransponíveis sem habilidades especiais.
const DEFAULT_MAX_SLOPE_RATIO: float = 1.5

## @const DEFAULT_TOLERANCE_FACTOR (float)
## O que: Multiplicador de tolerância para compensar flutuação de jitter de rede e perda de pacotes (1.3 = 30%).
## Porque: Previne correções bruscas (rubberbanding) por latência comum.
const DEFAULT_TOLERANCE_FACTOR: float = 1.3

## @const MIN_HORIZONTAL_MOVE_THRESHOLD (float)
## O que: Deslocamento horizontal mínimo em metros para considerar movimento ativo (0.1m).
## Porque: Evita rejeitar micro-movimentos imperceptíveis.
const MIN_HORIZONTAL_MOVE_THRESHOLD: float = 0.1


func validate_step(
	from_pos: Vector3,
	to_pos: Vector3,
	sampler: HeightfieldSamplerClass = null,
	hole_mask: TerrainHoleMaskClass = null,
	delta_time: float = DEFAULT_DELTA_TIME,
	max_speed: float = DEFAULT_MAX_SPEED,
	max_slope_ratio: float = DEFAULT_MAX_SLOPE_RATIO,
	tolerance_factor: float = DEFAULT_TOLERANCE_FACTOR,
) -> Dictionary:
	var result = {
		"valid": true,
		"corrected_pos": to_pos,
		"reason": "OK",
	}

	# 1. Validação de Velocidade e Distância Horizontal (Prevenção de Speedhack e Teleporte)
	var horiz_dist = Vector2(to_pos.x - from_pos.x, to_pos.z - from_pos.z).length()
	var max_allowed_dist = max_speed * delta_time * tolerance_factor

	if horiz_dist > max_allowed_dist and horiz_dist > MIN_HORIZONTAL_MOVE_THRESHOLD:
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

		# Tolerância vertical de gravidade/solo
		result["corrected_pos"] = Vector3(to_pos.x, ground_y, to_pos.z)

	return result
