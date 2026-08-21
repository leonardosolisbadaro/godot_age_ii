## @file environment_zone_data.gd
## @path res://src/domain/environment_zone_data.gd
##
## @description
## Entidade de domínio pura representando as condições atmosféricas, iluminação solar/lunar,
## parâmetros de névoa volumétrica e volumes aquáticos de uma zona de mapa.
##
## @created 2026-08-19
## @updated 2026-08-20
##
## @author Leonardo S. Badaró
extends RefCounted

# ==============================================================================
# CONSTANTES SEMÂNTICAS DE AMBIENTE E ATMOSFERA
# ==============================================================================

## @const DEFAULT_SUN_DIRECTION (Vector3)
## O que: Direção solar padrão (apontando suavemente para baixo em ângulo oblíquo).
## Porque: Iluminação natural equilibrada.
const DEFAULT_SUN_DIRECTION: Vector3 = Vector3(0.0, -0.866, 0.5)

## @const DEFAULT_MOON_DIRECTION (Vector3)
## O que: Direção lunar padrão (apontando em oposição ao Sol).
## Porque: Ciclo de iluminação noturna.
const DEFAULT_MOON_DIRECTION: Vector3 = Vector3(0.0, 0.866, -0.5)

## @const DEFAULT_SUN_ENERGY (float)
## O que: Intensidade de energia luminosa solar padrão (1.0).
## Porque: Calibração de luz direta padrão.
const DEFAULT_SUN_ENERGY: float = 1.0

## @const DEFAULT_MOON_ENERGY (float)
## O que: Intensidade de energia luminosa lunar padrão (0.2).
## Porque: Luz difusa noturna.
const DEFAULT_MOON_ENERGY: float = 0.2

## @const DEFAULT_AMBIENT_ENERGY (float)
## O que: Intensidade de energia da luz ambiente padrão (1.0).
## Porque: Preenchimento de sombras.
const DEFAULT_AMBIENT_ENERGY: float = 1.0

## @const DEFAULT_FOG_START_METERS (float)
## O que: Distância inicial da névoa de horizonte em metros (80.0m).
## Porque: Mantém o entorno do avatar perfeitamente nítido.
const DEFAULT_FOG_START_METERS: float = 80.0

## @const DEFAULT_FOG_END_METERS (float)
## O que: Distância máxima da névoa em metros (6400.0m).
## Porque: Esconde o corte de visão de chunks distantes de forma homogênea.
const DEFAULT_FOG_END_METERS: float = 6400.0

# ==============================================================================
# PROPRIEDADES DA ENTIDADE
# ==============================================================================

var zone_name: String = ""

# Iluminação Solar (Sol)
var sun_direction: Vector3 = DEFAULT_SUN_DIRECTION.normalized()
var sun_color: Color = Color.WHITE
var sun_energy: float = DEFAULT_SUN_ENERGY

# Iluminação Lunar (Lua)
var moon_direction: Vector3 = DEFAULT_MOON_DIRECTION.normalized()
var moon_color: Color = Color(0.6, 0.7, 0.9, 1.0)
var moon_energy: float = DEFAULT_MOON_ENERGY

# Luz Ambiente e Atmosfera
var ambient_light_color: Color = Color(0.2, 0.2, 0.25, 1.0)
var ambient_light_energy: float = DEFAULT_AMBIENT_ENERGY

# Névoa de Distância (Distance Fog)
var fog_enabled: bool = true
var fog_color: Color = Color(0.7, 0.8, 0.9, 1.0)
var fog_start_meters: float = DEFAULT_FOG_START_METERS
var fog_end_meters: float = DEFAULT_FOG_END_METERS

# Volumes de Água { "WaterVolume0": { "water_z_meters": float, "is_water_zone": bool } }
var water_volumes: Dictionary = { }


func _init(p_zone_name: String = "") -> void:
	zone_name = p_zone_name


func from_recipe_dictionary(dict: Dictionary) -> void:
	var sun_dict = dict.get("sunlight", dict.get("sun_light", { }))
	if not sun_dict.is_empty():
		var dir_arr = sun_dict.get("direction", [sun_direction.x, sun_direction.y, sun_direction.z])
		if dir_arr.size() >= 3:
			sun_direction = Vector3(float(dir_arr[0]), float(dir_arr[1]), float(dir_arr[2])).normalized()
		var col_arr = sun_dict.get("color_rgb", [1.0, 1.0, 1.0])
		if col_arr.size() >= 3:
			sun_color = Color(float(col_arr[0]), float(col_arr[1]), float(col_arr[2]))
		sun_energy = float(sun_dict.get("energy", sun_energy))

	var moon_dict = dict.get("moonlight", dict.get("moon_light", { }))
	if not moon_dict.is_empty():
		var dir_arr = moon_dict.get(
			"direction",
			[moon_direction.x, moon_direction.y, moon_direction.z],
		)
		if dir_arr.size() >= 3:
			moon_direction = Vector3(float(dir_arr[0]), float(dir_arr[1]), float(dir_arr[2])).normalized()
		var col_arr = moon_dict.get("color_rgb", [0.6, 0.7, 0.9])
		if col_arr.size() >= 3:
			moon_color = Color(float(col_arr[0]), float(col_arr[1]), float(col_arr[2]))
		moon_energy = float(moon_dict.get("energy", moon_energy))

	var amb_dict = dict.get("ambient_lighting", dict.get("ambient", { }))
	if not amb_dict.is_empty():
		var col_arr = amb_dict.get("color_rgb", [0.2, 0.2, 0.25])
		if col_arr.size() >= 3:
			ambient_light_color = Color(float(col_arr[0]), float(col_arr[1]), float(col_arr[2]))
		ambient_light_energy = float(amb_dict.get("energy", ambient_light_energy))

	var fog_dict = dict.get("distance_fog", dict.get("fog", { }))
	if not fog_dict.is_empty():
		fog_enabled = bool(fog_dict.get("enabled", fog_enabled))
		var col_arr = fog_dict.get("color_rgb", [0.7, 0.8, 0.9])
		if col_arr.size() >= 3:
			fog_color = Color(float(col_arr[0]), float(col_arr[1]), float(col_arr[2]))
		var dist_arr = fog_dict.get("distance_range_meters", [fog_start_meters, fog_end_meters])
		if dist_arr.size() >= 2:
			fog_start_meters = float(dist_arr[0])
			fog_end_meters = float(dist_arr[1])

	var raw_wv = dict.get("water_volumes", { })
	if raw_wv is Dictionary:
		water_volumes = raw_wv
	else:
		water_volumes = { }


func is_submerged_at(world_pos: Vector3) -> bool:
	for v_name in water_volumes.keys():
		var wv = water_volumes[v_name]
		if not (wv is Dictionary):
			continue
		var water_level = float(wv.get("water_z_meters", wv.get("surface_y_m", 0.0)))
		if world_pos.y < water_level:
			return true
	return false


func get_water_depth_at(world_pos: Vector3) -> float:
	var max_depth: float = 0.0
	for v_name in water_volumes.keys():
		var wv = water_volumes[v_name]
		if not (wv is Dictionary):
			continue
		var water_level = float(wv.get("water_z_meters", wv.get("surface_y_m", 0.0)))
		if world_pos.y < water_level:
			var depth = water_level - world_pos.y
			if depth > max_depth:
				max_depth = depth
	return max_depth
