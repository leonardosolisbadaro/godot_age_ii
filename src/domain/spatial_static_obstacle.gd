## @file spatial_static_obstacle.gd
## @path res://src/domain/spatial_static_obstacle.gd
##
## @description
## Entidade de domínio puro que encapsula a geometria analítica de um obstáculo
## estático (cilindro de tronco, caixa AABB ou segmento de parede) para física autoritativa no servidor.
##
## @created 2026-08-21
## @updated 2026-08-21
##
## @author Leonardo S. Badaró
extends RefCounted

enum ShapeType {
	CYLINDER,
	AABB_BOX,
	WALL_SEGMENT
}

var obstacle_id: String = ""
var shape_type: ShapeType = ShapeType.CYLINDER

# Propriedades para CYLINDER (Troncos de árvore, pilares, postes)
var center: Vector2 = Vector2.ZERO # (X, Z) horizontal
var radius: float = 0.5
var min_y: float = -9999.0
var max_y: float = 9999.0

# Propriedades para AABB_BOX (Rochas, caixas, blocos)
var box_min: Vector3 = Vector3.ZERO
var box_max: Vector3 = Vector3.ZERO

# Propriedades para WALL_SEGMENT (Paredes, cercas)
var wall_start: Vector2 = Vector2.ZERO # (X, Z)
var wall_end: Vector2 = Vector2.ZERO # (X, Z)
var wall_thickness: float = 0.3


static func create_cylinder(
	id: String,
	p_center: Vector2,
	p_radius: float,
	p_min_y: float,
	p_max_y: float
) -> RefCounted:
	var obs = new()
	obs.obstacle_id = id
	obs.shape_type = ShapeType.CYLINDER
	obs.center = p_center
	obs.radius = maxf(0.1, p_radius)
	obs.min_y = p_min_y
	obs.max_y = p_max_y
	return obs


static func create_box(
	id: String,
	p_min: Vector3,
	p_max: Vector3
) -> RefCounted:
	var obs = new()
	obs.obstacle_id = id
	obs.shape_type = ShapeType.AABB_BOX
	obs.box_min = Vector3(
		minf(p_min.x, p_max.x),
		minf(p_min.y, p_max.y),
		minf(p_min.z, p_max.z)
	)
	obs.box_max = Vector3(
		maxf(p_min.x, p_max.x),
		maxf(p_min.y, p_max.y),
		maxf(p_min.z, p_max.z)
	)
	obs.min_y = obs.box_min.y
	obs.max_y = obs.box_max.y
	return obs


static func create_wall_segment(
	id: String,
	p_start: Vector2,
	p_end: Vector2,
	p_min_y: float,
	p_max_y: float,
	thickness: float = 0.4
) -> RefCounted:
	var obs = new()
	obs.obstacle_id = id
	obs.shape_type = ShapeType.WALL_SEGMENT
	obs.wall_start = p_start
	obs.wall_end = p_end
	obs.min_y = p_min_y
	obs.max_y = p_max_y
	obs.wall_thickness = maxf(0.1, thickness)
	return obs


func get_bounding_rect_2d() -> Rect2:
	match shape_type:
		ShapeType.CYLINDER:
			var r = radius
			return Rect2(center.x - r, center.y - r, r * 2.0, r * 2.0)
		ShapeType.AABB_BOX:
			var min_x = box_min.x
			var min_z = box_min.z
			var w = box_max.x - min_x
			var d = box_max.z - min_z
			return Rect2(min_x, min_z, w, d)
		ShapeType.WALL_SEGMENT:
			var min_x = minf(wall_start.x, wall_end.x) - wall_thickness
			var min_z = minf(wall_start.y, wall_end.y) - wall_thickness
			var max_x = maxf(wall_start.x, wall_end.x) + wall_thickness
			var max_z = maxf(wall_start.y, wall_end.y) + wall_thickness
			return Rect2(min_x, min_z, max_x - min_x, max_z - min_z)
	return Rect2(0, 0, 0, 0)


func intersects_point_2d(p_x: float, p_z: float, entity_radius: float = 0.0, p_y: float = 0.0) -> bool:
	# Verificação de altitude vertical
	if p_y < min_y or p_y > max_y:
		return false

	match shape_type:
		ShapeType.CYLINDER:
			var total_r = radius + entity_radius
			var dx = p_x - center.x
			var dz = p_z - center.y
			return (dx * dx + dz * dz) <= (total_r * total_r)

		ShapeType.AABB_BOX:
			var er = entity_radius
			return (
				p_x >= (box_min.x - er) and p_x <= (box_max.x + er) and
				p_z >= (box_min.z - er) and p_z <= (box_max.z + er)
			)

		ShapeType.WALL_SEGMENT:
			return _dist_point_to_segment_sq(Vector2(p_x, p_z), wall_start, wall_end) <= ((wall_thickness + entity_radius) * (wall_thickness + entity_radius))

	return false


func intersects_segment_3d(from_pos: Vector3, to_pos: Vector3, entity_radius: float = 0.0) -> bool:
	# Verificação de intervalo vertical
	var seg_min_y = minf(from_pos.y, to_pos.y)
	var seg_max_y = maxf(from_pos.y, to_pos.y)
	if seg_max_y < min_y or seg_min_y > max_y:
		return false

	var p1 = Vector2(from_pos.x, from_pos.z)
	var p2 = Vector2(to_pos.x, to_pos.z)

	match shape_type:
		ShapeType.CYLINDER:
			var total_r = radius + entity_radius
			return _dist_point_to_segment_sq(center, p1, p2) <= (total_r * total_r)

		ShapeType.AABB_BOX:
			# Teste de interseção 2D de linha contra AABB expandido
			var er = entity_radius
			var r_min = Vector2(box_min.x - er, box_min.z - er)
			var r_max = Vector2(box_max.x + er, box_max.z + er)
			return _segment_intersects_aabb_2d(p1, p2, r_min, r_max)

		ShapeType.WALL_SEGMENT:
			return _segments_intersect_2d_with_thickness(p1, p2, wall_start, wall_end, wall_thickness + entity_radius)

	return false


func _dist_point_to_segment_sq(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab = b - a
	var ab_len_sq = ab.length_squared()
	if ab_len_sq <= 0.0001:
		return (p - a).length_squared()

	var t = clampf((p - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	var proj = a + (ab * t)
	return (p - proj).length_squared()


func _segment_intersects_aabb_2d(p1: Vector2, p2: Vector2, r_min: Vector2, r_max: Vector2) -> bool:
	if (p1.x >= r_min.x and p1.x <= r_max.x and p1.y >= r_min.y and p1.y <= r_max.y) or \
	   (p2.x >= r_min.x and p2.x <= r_max.x and p2.y >= r_min.y and p2.y <= r_max.y):
		return true

	var d = p2 - p1
	var t_min: float = 0.0
	var t_max: float = 1.0

	# Eixo X
	if absf(d.x) < 0.0001:
		if p1.x < r_min.x or p1.x > r_max.x:
			return false
	else:
		var t1 = (r_min.x - p1.x) / d.x
		var t2 = (r_max.x - p1.x) / d.x
		var near_t = minf(t1, t2)
		var far_t = maxf(t1, t2)
		t_min = maxf(t_min, near_t)
		t_max = minf(t_max, far_t)
		if t_min > t_max:
			return false

	# Eixo Y (Z no mundo)
	if absf(d.y) < 0.0001:
		if p1.y < r_min.y or p1.y > r_max.y:
			return false
	else:
		var t1 = (r_min.y - p1.y) / d.y
		var t2 = (r_max.y - p1.y) / d.y
		var near_t = minf(t1, t2)
		var far_t = maxf(t1, t2)
		t_min = maxf(t_min, near_t)
		t_max = minf(t_max, far_t)
		if t_min > t_max:
			return false

	return true


func _segments_intersect_2d_with_thickness(p1: Vector2, p2: Vector2, w1: Vector2, w2: Vector2, max_dist: float) -> bool:
	# Teste de proximidade de menor distância entre dois segmentos
	var d1 = _dist_point_to_segment_sq(p1, w1, w2)
	var d2 = _dist_point_to_segment_sq(p2, w1, w2)
	var d3 = _dist_point_to_segment_sq(w1, p1, p2)
	var d4 = _dist_point_to_segment_sq(w2, p1, p2)
	var min_d_sq = minf(minf(d1, d2), minf(d3, d4))
	return min_d_sq <= (max_dist * max_dist)
