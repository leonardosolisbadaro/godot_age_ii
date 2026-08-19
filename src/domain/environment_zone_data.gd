## @file environment_zone_data.gd
## @path res://src/domain/environment_zone_data.gd
##
## @description
## Entidade de domínio pura representando as condições atmosféricas, iluminação solar/lunar,
## parâmetros de névoa volumétrica e volumes aquáticos de uma zona de mapa.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends RefCounted

var zone_name: String = ""

# Iluminação Solar (Sol)
var sun_direction: Vector3 = Vector3(0.0, -0.866, 0.5).normalized()
var sun_color: Color = Color.WHITE
var sun_energy: float = 1.0

# Iluminação Lunar (Lua)
var moon_direction: Vector3 = Vector3(0.0, 0.866, -0.5).normalized()
var moon_color: Color = Color(0.6, 0.7, 0.9, 1.0)
var moon_energy: float = 0.2

# Luz Ambiente e Atmosfera
var ambient_light_color: Color = Color(0.2, 0.2, 0.25, 1.0)
var ambient_light_energy: float = 1.0

# Névoa de Distância (Distance Fog)
var fog_enabled: bool = true
var fog_color: Color = Color(0.7, 0.8, 0.9, 1.0)
var fog_start_meters: float = 80.0
var fog_end_meters: float = 6400.0

# Volumes de Água [{ "name": String, "water_z_meters": float, "is_water_zone": bool }]
var water_volumes: Array = []


func _init(p_zone_name: String = "") -> void:
	zone_name = p_zone_name


func from_recipe_dictionary(dict: Dictionary) -> void:
	var sun_dict = dict.get("sun_light", {})
	if not sun_dict.is_empty():
		var dir_arr = sun_dict.get("direction", [sun_direction.x, sun_direction.y, sun_direction.z])
		if dir_arr.size() >= 3:
			sun_direction = Vector3(float(dir_arr[0]), float(dir_arr[1]), float(dir_arr[2])).normalized()
		var col_arr = sun_dict.get("color_rgb", [1.0, 1.0, 1.0])
		if col_arr.size() >= 3:
			sun_color = Color(float(col_arr[0]), float(col_arr[1]), float(col_arr[2]))
		sun_energy = float(sun_dict.get("energy", sun_energy))

	var moon_dict = dict.get("moon_light", {})
	if not moon_dict.is_empty():
		var dir_arr = moon_dict.get("direction", [moon_direction.x, moon_direction.y, moon_direction.z])
		if dir_arr.size() >= 3:
			moon_direction = Vector3(float(dir_arr[0]), float(dir_arr[1]), float(dir_arr[2])).normalized()
		var col_arr = moon_dict.get("color_rgb", [0.6, 0.7, 0.9])
		if col_arr.size() >= 3:
			moon_color = Color(float(col_arr[0]), float(col_arr[1]), float(col_arr[2]))
		moon_energy = float(moon_dict.get("energy", moon_energy))

	var amb_dict = dict.get("ambient", {})
	if not amb_dict.is_empty():
		var col_arr = amb_dict.get("color_rgb", [0.2, 0.2, 0.25])
		if col_arr.size() >= 3:
			ambient_light_color = Color(float(col_arr[0]), float(col_arr[1]), float(col_arr[2]))
		ambient_light_energy = float(amb_dict.get("energy", ambient_light_energy))

	var fog_dict = dict.get("fog", {})
	if not fog_dict.is_empty():
		fog_enabled = bool(fog_dict.get("enabled", fog_enabled))
		var col_arr = fog_dict.get("color_rgb", [0.7, 0.8, 0.9])
		if col_arr.size() >= 3:
			fog_color = Color(float(col_arr[0]), float(col_arr[1]), float(col_arr[2]))
		var dist_arr = fog_dict.get("distance_range_meters", [fog_start_meters, fog_end_meters])
		if dist_arr.size() >= 2:
			fog_start_meters = float(dist_arr[0])
			fog_end_meters = float(dist_arr[1])

	water_volumes = dict.get("water_volumes", water_volumes)


func is_submerged_at(world_pos: Vector3) -> bool:
	for wv in water_volumes:
		var water_level = float(wv.get("water_z_meters", 0.0))
		if world_pos.y < water_level:
			return true
	return false


func get_water_depth_at(world_pos: Vector3) -> float:
	var max_depth: float = 0.0
	for wv in water_volumes:
		var water_level = float(wv.get("water_z_meters", 0.0))
		if world_pos.y < water_level:
			var depth = water_level - world_pos.y
			if depth > max_depth:
				max_depth = depth
	return max_depth
