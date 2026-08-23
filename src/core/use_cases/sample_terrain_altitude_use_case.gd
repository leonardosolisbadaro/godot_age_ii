## @file sample_terrain_altitude_use_case.gd
## @path res://src/core/use_cases/sample_terrain_altitude_use_case.gd
##
## @description
## Caso de uso puro de amostragem de altitude e normais de terreno em O(1).
## Executa interpolacao bilinear continua sobre arrays de alturas sem depender de nos da Engine.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
class_name SampleTerrainAltitudeUseCase
extends RefCounted

# ==============================================================================
# AMOSTRAGEM DE ALTITUDE (INTERPOLAÇÃO BILINEAR O(1))
# ==============================================================================


## Amostra a altitude (cota Y em metros) em uma posicao local do chunk (0 a chunk_size_meters).
static func sample_altitude(
	local_x: float,
	local_z: float,
	heightfield: PackedFloat32Array,
	resolution: int = 256,
	chunk_size_meters: float = 163.84,
) -> float:
	if heightfield.is_empty() or resolution <= 1:
		return 0.0

	var norm_x = clampf(local_x / chunk_size_meters, 0.0, 1.0) * float(resolution - 1)
	var norm_z = clampf(local_z / chunk_size_meters, 0.0, 1.0) * float(resolution - 1)

	var x0 = clampi(int(floor(norm_x)), 0, resolution - 1)
	var z0 = clampi(int(floor(norm_z)), 0, resolution - 1)
	var x1 = clampi(x0 + 1, 0, resolution - 1)
	var z1 = clampi(z0 + 1, 0, resolution - 1)

	var fx = norm_x - float(x0)
	var fz = norm_z - float(z0)

	var h00 = heightfield[(z0 * resolution) + x0]
	var h10 = heightfield[(z0 * resolution) + x1]
	var h01 = heightfield[(z1 * resolution) + x0]
	var h11 = heightfield[(z1 * resolution) + x1]

	var h_top = lerpf(h00, h10, fx)
	var h_bot = lerpf(h01, h11, fx)
	return lerpf(h_top, h_bot, fz)


## Amostra a normal do terreno no ponto atraves do gradiente de altura dos vizinhos.
static func sample_normal(
	local_x: float,
	local_z: float,
	heightfield: PackedFloat32Array,
	resolution: int = 256,
	chunk_size_meters: float = 163.84,
) -> Vector3:
	var delta = chunk_size_meters / float(resolution - 1)
	var h_l = sample_altitude(local_x - delta, local_z, heightfield, resolution, chunk_size_meters)
	var h_r = sample_altitude(local_x + delta, local_z, heightfield, resolution, chunk_size_meters)
	var h_u = sample_altitude(local_x, local_z - delta, heightfield, resolution, chunk_size_meters)
	var h_d = sample_altitude(local_x, local_z + delta, heightfield, resolution, chunk_size_meters)

	var normal = Vector3(h_l - h_r, 2.0 * delta, h_u - h_d)
	return normal.normalized()
