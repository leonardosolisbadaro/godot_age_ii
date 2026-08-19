## @file terrain_chunk_data.gd
## @path res://src/domain/terrain_chunk_data.gd
##
## @description
## Entidade de domínio pura representando as dimensões, escala, limites espaciais
## e metadados de elevação de um chunk de terreno no mundo (Lineage II / Godotage II).
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends RefCounted

var chunk_name: String = ""
var chunk_x: int = 0
var chunk_y: int = 0

var grid_width: int = 256
var grid_depth: int = 256

var cell_size_x: float = 2.438
var cell_size_z: float = 2.438

var total_width_meters: float = 624.15
var total_depth_meters: float = 624.15

var world_origin: Vector3 = Vector3.ZERO
var min_altitude: float = 0.0
var max_altitude: float = 0.0


func _init(
	p_name: String = "",
	p_x: int = 0,
	p_y: int = 0,
	p_origin: Vector3 = Vector3.ZERO,
	p_width: float = 624.15,
	p_depth: float = 624.15
) -> void:
	chunk_name = p_name
	chunk_x = p_x
	chunk_y = p_y
	world_origin = p_origin
	total_width_meters = p_width
	total_depth_meters = p_depth
	if grid_width > 1:
		cell_size_x = total_width_meters / float(grid_width - 1)
	if grid_depth > 1:
		cell_size_z = total_depth_meters / float(grid_depth - 1)


func from_meta_dictionary(dict: Dictionary) -> void:
	chunk_name = dict.get("chunk_name", chunk_name)
	var indices = dict.get("chunk_indices", [chunk_x, chunk_y])
	if indices.size() >= 2:
		chunk_x = int(indices[0])
		chunk_y = int(indices[1])

	var res = dict.get("grid_resolution", [grid_width, grid_depth])
	if res.size() >= 2:
		grid_width = int(res[0])
		grid_depth = int(res[1])

	var dims = dict.get("chunk_dimensions_meters", [total_width_meters, total_depth_meters])
	if dims.size() >= 2:
		total_width_meters = float(dims[0])
		total_depth_meters = float(dims[1])

	var cell = dict.get("cell_size_meters", [cell_size_x, cell_size_z])
	if cell.size() >= 2:
		cell_size_x = float(cell[0])
		cell_size_z = float(cell[1])
	elif grid_width > 1 and grid_depth > 1:
		cell_size_x = total_width_meters / float(grid_width - 1)
		cell_size_z = total_depth_meters / float(grid_depth - 1)

	var orig = dict.get("world_origin_meters", [world_origin.x, world_origin.y, world_origin.z])
	if orig.size() >= 3:
		world_origin = Vector3(float(orig[0]), float(orig[1]), float(orig[2]))

	var alt = dict.get("altitude_meters", {})
	min_altitude = float(alt.get("min", min_altitude))
	max_altitude = float(alt.get("max", max_altitude))


func contains_world_point(world_x: float, world_z: float) -> bool:
	var half_w = total_width_meters / 2.0
	var half_d = total_depth_meters / 2.0
	return (
		world_x >= (world_origin.x - half_w) and world_x <= (world_origin.x + half_w) and
		world_z >= (world_origin.z - half_d) and world_z <= (world_origin.z + half_d)
	)


func get_local_coordinates(world_x: float, world_z: float) -> Vector2:
	var half_w = total_width_meters / 2.0
	var half_d = total_depth_meters / 2.0
	return Vector2(
		world_x - (world_origin.x - half_w),
		world_z - (world_origin.z - half_d)
	)


func get_world_bounds_2d() -> Rect2:
	var half_w = total_width_meters / 2.0
	var half_d = total_depth_meters / 2.0
	return Rect2(
		world_origin.x - half_w,
		world_origin.z - half_d,
		total_width_meters,
		total_depth_meters
	)
