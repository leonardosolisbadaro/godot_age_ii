## @file environment_zone_adapter.gd
## @path res://src/adapters/environment_zone_adapter.gd
##
## @description
## Adaptador de interface que traduz a entidade EnvironmentZoneData para as
## propriedades visuais de nós DirectionalLight3D e WorldEnvironment no Godot 4.
##
## @created 2026-08-19
## @updated 2026-08-20
##
## @author Leonardo S. Badaró
extends RefCounted

const EnvironmentZoneDataClass = preload("res://src/domain/environment_zone_data.gd")

# ==============================================================================
# CONSTANTES SEMÂNTICAS DE ILUMINAÇÃO E SOMBRAS
# ==============================================================================

## @const SHADOW_MAX_DISTANCE (float)
## O que: Distância máxima de alcance das sombras em metros (400.0m).
## Porque: Cobre o campo de visão imediato com fidelidade mantendo alta performance.
const SHADOW_MAX_DISTANCE: float = 400.0

## @const SHADOW_SPLIT_1 (float)
## O que: Ponto de divisão da primeira cascata de sombra PSSM (0.08 = 8%).
## Porque: Máxima nitidez de sombras próximas ao avatar.
const SHADOW_SPLIT_1: float = 0.08

## @const SHADOW_SPLIT_2 (float)
## O que: Ponto de divisão da segunda cascata de sombra PSSM (0.20 = 20%).
## Porque: Transição suave para média distância.
const SHADOW_SPLIT_2: float = 0.20

## @const SHADOW_SPLIT_3 (float)
## O que: Ponto de divisão da terceira cascata de sombra PSSM (0.50 = 50%).
## Porque: Transição para sombras de longa distância.
const SHADOW_SPLIT_3: float = 0.50

## @const SHADOW_FADE_START (float)
## O que: Ponto relativo de atenuação do corte de sombras (0.85 = 85%).
## Porque: Suaviza o limite final das sombras no horizonte.
const SHADOW_FADE_START: float = 0.85

## @const DEFAULT_SKY_CONTRIBUTION (float)
## O que: Fator de contribuição do céu para a luz ambiente hemisférica (0.5).
## Porque: Iluminação suave em áreas sombreadas.
const DEFAULT_SKY_CONTRIBUTION: float = 0.5

## @const MIN_AMBIENT_LIGHT_ENERGY (float)
## O que: Nível mínimo de energia de luz ambiente (0.6).
## Porque: Previne que vales e sombras fiquem totalmente pretos.
const MIN_AMBIENT_LIGHT_ENERGY: float = 0.6

## @const DEFAULT_FOG_DENSITY (float)
## O que: Densidade volumétrica da névoa de distância (0.00002).
## Porque: Névoa atmosférica suave de mundo aberto.
const DEFAULT_FOG_DENSITY: float = 0.00002


func apply_to_directional_light(env_data: EnvironmentZoneDataClass, light_node: DirectionalLight3D) -> void:
	if not env_data or not light_node:
		return

	light_node.light_color = env_data.sun_color
	light_node.light_energy = env_data.sun_energy

	# Configura PSSM de 4 divisões paralelas para sombras contínuas sem queda de FPS
	light_node.shadow_enabled = true
	light_node.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	light_node.directional_shadow_max_distance = SHADOW_MAX_DISTANCE
	light_node.directional_shadow_split_1 = SHADOW_SPLIT_1
	light_node.directional_shadow_split_2 = SHADOW_SPLIT_2
	light_node.directional_shadow_split_3 = SHADOW_SPLIT_3
	light_node.directional_shadow_fade_start = SHADOW_FADE_START

	# Orienta o nó de luz para apontar na direção do Sol
	if env_data.sun_direction.length_squared() > 0.001:
		light_node.basis = Basis.looking_at(env_data.sun_direction, Vector3.UP)


func apply_to_world_environment(
	env_data: EnvironmentZoneDataClass,
	world_env_node: WorldEnvironment,
) -> void:
	if not env_data or not world_env_node:
		return

	var env = world_env_node.environment
	if not env:
		env = Environment.new()
		world_env_node.environment = env

	# Configura céu e atmosfera suave
	var sky = Sky.new()
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.40, 0.60, 0.85)
	sky_mat.sky_horizon_color = Color(0.72, 0.80, 0.88)
	sky_mat.ground_bottom_color = Color(0.35, 0.40, 0.30)
	sky_mat.ground_horizon_color = Color(0.72, 0.80, 0.88)
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY

	# Configura luz ambiente com contribuição hemisférica equilibrada
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = DEFAULT_SKY_CONTRIBUTION
	env.ambient_light_color = env_data.ambient_light_color
	env.ambient_light_energy = max(MIN_AMBIENT_LIGHT_ENERGY, env_data.ambient_light_energy)

	# Configura névoa volumétrica/distância suave
	env.fog_enabled = env_data.fog_enabled
	env.fog_light_color = env_data.fog_color
	env.fog_density = DEFAULT_FOG_DENSITY
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
