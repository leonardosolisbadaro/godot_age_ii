## @file heightfield_sampler.gd
## @path res://src/domain/heightfield_sampler.gd
##
## @description
## Entidade de domínio pura para amostragem matemática e interpolação bilinear
## em tempo constante O(1) de matrizes de elevação de terreno em coordenadas mundiais.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends RefCounted

const TerrainChunkDataClass = preload("res://src/domain/terrain_chunk_data.gd")

var heights: PackedFloat32Array
var grid_width: int = 0
var grid_depth: int = 0
var cell_size_x: float = 1.0
var cell_size_z: float = 1.0
var world_origin: Vector3 = Vector3.ZERO
var total_width: float = 0.0
var total_depth: float = 0.0


func _init(
	p_heights: PackedFloat32Array = PackedFloat32Array(),
	p_grid_w: int = 0,
	p_grid_d: int = 0,
	p_cell_x: float = 1.0,
	p_cell_z: float = 1.0,
	p_origin: Vector3 = Vector3.ZERO,
	p_total_w: float = 0.0,
	p_total_d: float = 0.0
) -> void:
	heights = p_heights
	grid_width = p_grid_w
	grid_depth = p_grid_d
	cell_size_x = p_cell_x
	cell_size_z = p_cell_z
	world_origin = p_origin
	total_width = p_total_w
	total_depth = p_total_d


static func from_chunk_data_and_bytes(chunk_data: TerrainChunkDataClass, raw_bytes: PackedByteArray) -> Variant:
	var float_count = raw_bytes.size() / 4
	var float_arr = PackedFloat32Array()
	float_arr.resize(float_count)
	for i in range(float_count):
		float_arr[i] = raw_bytes.decode_float(i * 4)

	var script_res = load("res://src/domain/heightfield_sampler.gd")
	return script_res.new(
		float_arr,
		chunk_data.grid_width,
		chunk_data.grid_depth,
		chunk_data.cell_size_x,
		chunk_data.cell_size_z,
		chunk_data.world_origin,
		chunk_data.total_width_meters,
		chunk_data.total_depth_meters
	)


func get_height_at(world_x: float, world_z: float) -> float:
	if heights.is_empty() or grid_width <= 0 or grid_depth <= 0:
		return world_origin.y

	# 1. Converte a coordenada de mundo para coordenadas locais [0 .. total_width/depth]
	var half_w = total_width / 2.0
	var half_d = total_depth / 2.0
	var local_x = world_x - (world_origin.x - half_w)
	var local_z = world_z - (world_origin.z - half_d)

	# 2. Converte para coordenadas normalizadas [0 .. 1] e mapeia para a grade de vértices [0 .. grid - 1]
	var norm_x = clampf(local_x / maxf(total_width, 0.001), 0.0, 1.0)
	var norm_z = clampf(local_z / maxf(total_depth, 0.001), 0.0, 1.0)

	var u = norm_x * float(grid_width - 1)
	var v = norm_z * float(grid_depth - 1)

	# 3. Identifica a célula (quad) e os fatores de interpolação sub-célula [0..1]
	var gx0 = clampi(int(floor(u)), 0, grid_width - 1)
	var gz0 = clampi(int(floor(v)), 0, grid_depth - 1)
	var gx1 = mini(gx0 + 1, grid_width - 1)
	var gz1 = mini(gz0 + 1, grid_depth - 1)

	var tx = u - float(gx0)
	var tz = v - float(gz0)

	# 4. Amostra os 4 vértices do quad
	var h00 = heights[gz0 * grid_width + gx0]
	var h10 = heights[gz0 * grid_width + gx1]
	var h01 = heights[gz1 * grid_width + gx0]
	var h11 = heights[gz1 * grid_width + gx1]

	# 5. Interpolação Bilinear somada à altitude mundial da origem do chunk
	var h_top = lerpf(h00, h10, tx)
	var h_bottom = lerpf(h01, h11, tx)
	return world_origin.y + lerpf(h_top, h_bottom, tz)


func get_normal_at(world_x: float, world_z: float, delta_step: float = 0.5) -> Vector3:
	var h_center = get_height_at(world_x, world_z)
	var h_right = get_height_at(world_x + delta_step, world_z)
	var h_forward = get_height_at(world_x, world_z + delta_step)

	var v_x = Vector3(delta_step, h_right - h_center, 0.0)
	var v_z = Vector3(0.0, h_forward - h_center, delta_step)

	var normal = v_z.cross(v_x).normalized()
	if normal.y < 0.0:
		normal = -normal
	return normal


func get_slope_ratio_at(world_x: float, world_z: float) -> float:
	var normal = get_normal_at(world_x, world_z)
	if normal.y >= 0.9999:
		return 0.0
	return sqrt(1.0 - normal.y * normal.y) / maxf(normal.y, 0.0001)
