## @file test_player_stats.gd
## @path res://tests/core/test_player_stats.gd
##
## @description
## Testes unitarios GUT AAA da entidade PlayerStats.
## Valida atributos basicos de Lineage II e formulas puras de velocidade em UU e metros.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
extends GutTest

const PlayerStatsClass = preload("res://src/core/domain/player_stats.gd")
const ScaleConverterClass = preload("res://src/core/domain/scale_converter.gd")


func test_player_stats_defaults() -> void:
	# Arrange & Act
	var stats = PlayerStatsClass.new()

	# Assert
	assert_eq(stats.dex, 30, "DEX padrao deve ser 30.")
	assert_eq(stats.str_stat, 40, "STR padrao deve ser 40.")
	assert_eq(stats.base_run_speed_uu, 120.0, "Velocidade de corrida base deve ser 120 UU/s.")
	assert_eq(stats.base_walk_speed_uu, 80.0, "Velocidade de caminhada base deve ser 80 UU/s.")
	assert_eq(stats.speed_multiplier, 1.0, "Multiplicador de velocidade padrao deve ser 1.0.")
	assert_eq(
		stats.weight_penalty_ratio,
		1.0,
		"Penalidade de peso padrao deve ser 1.0 (sem penalidade).",
	)


func test_effective_speed_calculations() -> void:
	# Arrange
	var stats = PlayerStatsClass.new()
	stats.base_run_speed_uu = 150.0
	stats.base_walk_speed_uu = 90.0
	stats.speed_multiplier = 1.2 # Buff de Wind Walk (+20%)
	stats.weight_penalty_ratio = 0.8 # Sobrecarga (-20%)

	# Act
	var run_uu = stats.get_effective_run_speed_uu()
	var walk_uu = stats.get_effective_walk_speed_uu()
	var run_meters = stats.get_effective_run_speed_meters()
	var walk_meters = stats.get_effective_walk_speed_meters()

	# Assert
	# 150 * 1.2 * 0.8 = 144.0 UU/s
	assert_almost_eq(run_uu, 144.0, 0.01, "Velocidade efetiva de corrida em UU deve ser 144.0.")
	# 90 * 1.2 * 0.8 = 86.4 UU/s
	assert_almost_eq(walk_uu, 86.4, 0.01, "Velocidade efetiva de caminhada em UU deve ser 86.4.")
	# 144.0 * 0.08 m/UU = 11.52 m/s
	assert_almost_eq(
		run_meters,
		11.52,
		0.01,
		"Velocidade efetiva de corrida em metros deve ser 11.52 m/s.",
	)
	# 86.4 * 0.08 m/UU = 6.912 m/s
	assert_almost_eq(
		walk_meters,
		6.912,
		0.01,
		"Velocidade efetiva de caminhada em metros deve ser 6.912 m/s.",
	)
