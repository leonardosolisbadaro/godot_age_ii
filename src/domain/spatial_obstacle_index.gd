## @file spatial_obstacle_index.gd
## @path res://src/domain/spatial_obstacle_index.gd
##
## @description
## Estrutura de aceleração espacial analítica particionada em grade 2D (O(1))
## para detecção ultrarrápida de colisões estáticas no servidor autoritativo.
##
## @created 2026-08-21
## @updated 2026-08-21
##
## @author Leonardo S. Badaró
extends RefCounted

const SpatialStaticObstacleClass = preload("res://src/domain/spatial_static_obstacle.gd")

const DEFAULT_CELL_SIZE: float = 16.0

var chunk_name: String = ""
var cell_size: float = DEFAULT_CELL_SIZE
var _grid: Dictionary = { } # Vector2i -> Array[SpatialStaticObstacle]
var _all_obstacles: Array = []


func _init(p_chunk_name: String = "", p_cell_size: float = DEFAULT_CELL_SIZE) -> void:
	chunk_name = p_chunk_name
	cell_size = maxf(4.0, p_cell_size)


func add_obstacle(obs: RefCounted) -> void:
	if not obs:
		return

	_all_obstacles.append(obs)
	var rect = obs.get_bounding_rect_2d()

	var min_cx = int(floor(rect.position.x / cell_size))
	var min_cz = int(floor(rect.position.y / cell_size))
	var max_cx = int(floor((rect.position.x + rect.size.x) / cell_size))
	var max_cz = int(floor((rect.position.y + rect.size.y) / cell_size))

	for cx in range(min_cx, max_cx + 1):
		for cz in range(min_cz, max_cz + 1):
			var cell_key = Vector2i(cx, cz)
			if not _grid.has(cell_key):
				_grid[cell_key] = []
			_grid[cell_key].append(obs)


func is_position_blocked(pos: Vector3, radius: float = 0.4) -> bool:
	var min_cx = int(floor((pos.x - radius) / cell_size))
	var min_cz = int(floor((pos.z - radius) / cell_size))
	var max_cx = int(floor((pos.x + radius) / cell_size))
	var max_cz = int(floor((pos.z + radius) / cell_size))

	var checked_ids = { }
	for cx in range(min_cx, max_cx + 1):
		for cz in range(min_cz, max_cz + 1):
			var cell_key = Vector2i(cx, cz)
			var cell_obstacles = _grid.get(cell_key, [])
			for obs in cell_obstacles:
				if checked_ids.has(obs.obstacle_id):
					continue
				checked_ids[obs.obstacle_id] = true
				if obs.intersects_point_2d(pos.x, pos.z, radius, pos.y):
					return true

	return false


func is_segment_blocked(from_pos: Vector3, to_pos: Vector3, radius: float = 0.4) -> bool:
	var min_x = minf(from_pos.x, to_pos.x) - radius
	var max_x = maxf(from_pos.x, to_pos.x) + radius
	var min_z = minf(from_pos.z, to_pos.z) - radius
	var max_z = maxf(from_pos.z, to_pos.z) + radius

	var min_cx = int(floor(min_x / cell_size))
	var min_cz = int(floor(min_z / cell_size))
	var max_cx = int(floor(max_x / cell_size))
	var max_cz = int(floor(max_z / cell_size))

	var checked_ids = { }
	for cx in range(min_cx, max_cx + 1):
		for cz in range(min_cz, max_cz + 1):
			var cell_key = Vector2i(cx, cz)
			var cell_obstacles = _grid.get(cell_key, [])
			for obs in cell_obstacles:
				if checked_ids.has(obs.obstacle_id):
					continue
				checked_ids[obs.obstacle_id] = true
				if obs.intersects_segment_3d(from_pos, to_pos, radius):
					return true

	return false


func get_obstacle_count() -> int:
	return _all_obstacles.size()


func clear() -> void:
	_grid.clear()
	_all_obstacles.clear()
