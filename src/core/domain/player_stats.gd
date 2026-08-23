## @file player_stats.gd
## @path res://src/core/domain/player_stats.gd
##
## @description
## Entidade pura do Core Domain que encapsula os atributos primários (DEX, STR, etc.)
## e calcula velocidades dinâmicas de deslocamento (corrida/caminhada) em UU e metros.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
class_name PlayerStats
extends RefCounted

const ScaleConverterClass = preload("res://src/core/domain/scale_converter.gd")

# ==============================================================================
# ATRIBUTOS PRIMÁRIOS DE LINEAGE II
# ==============================================================================

var str_stat: int = 40
var dex: int = 30
var con: int = 43
var int_stat: int = 21
var wit: int = 11
var men: int = 25

# ==============================================================================
# PARÂMETROS DE MOVIMENTAÇÃO
# ==============================================================================

var base_run_speed_uu: float = 120.0
var base_walk_speed_uu: float = 80.0
var speed_multiplier: float = 1.0 # Buffs/Debuffs (ex: Wind Walk, Slow)
var weight_penalty_ratio: float = 1.0 # Penalidade por sobrecarga (1.0 = 100% velocidade)


func _init(
	p_dex: int = 30,
	p_str: int = 40,
	p_run_uu: float = 120.0,
	p_walk_uu: float = 80.0,
) -> void:
	dex = p_dex
	str_stat = p_str
	base_run_speed_uu = p_run_uu
	base_walk_speed_uu = p_walk_uu


## Retorna a velocidade efetiva de corrida em Unreal Units por segundo (UU/s).
func get_effective_run_speed_uu() -> float:
	return base_run_speed_uu * speed_multiplier * weight_penalty_ratio


## Retorna a velocidade efetiva de caminhada em Unreal Units por segundo (UU/s).
func get_effective_walk_speed_uu() -> float:
	return base_walk_speed_uu * speed_multiplier * weight_penalty_ratio


## Retorna a velocidade efetiva de corrida convertida em Metros por segundo (m/s).
func get_effective_run_speed_meters() -> float:
	return ScaleConverterClass.uu_to_meters(get_effective_run_speed_uu())


## Retorna a velocidade efetiva de caminhada convertida em Metros por segundo (m/s).
func get_effective_walk_speed_meters() -> float:
	return ScaleConverterClass.uu_to_meters(get_effective_walk_speed_uu())
