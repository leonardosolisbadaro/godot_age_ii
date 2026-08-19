## @file test_heightfield_sampler.gd
## @path res://tests/unit/domain/test_heightfield_sampler.gd
##
## @description
## Testes unitários AAA para a entidade de domínio HeightfieldSampler.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends GutTest

const HeightfieldSamplerClass = preload("res://src/domain/heightfield_sampler.gd")
const TerrainChunkDataClass = preload("res://src/domain/terrain_chunk_data.gd")


func test_exact_grid_vertices_sampling() -> void:
	# Arrange: Grade 2x2 com alturas [0.0, 10.0, 20.0, 30.0], origem (0, 0, 0), dimensão 10x10 [-5..+5]
	var heights = PackedFloat32Array([
		0.0, 10.0,
		20.0, 30.0
	])
	var sampler = HeightfieldSamplerClass.new(
		heights,
		2, 2,
		10.0, 10.0,
		Vector3.ZERO,
		10.0, 10.0
	)

	# Act
	var h_top_left = sampler.get_height_at(-5.0, -5.0)
	var h_top_right = sampler.get_height_at(5.0, -5.0)
	var h_bottom_left = sampler.get_height_at(-5.0, 5.0)
	var h_bottom_right = sampler.get_height_at(5.0, 5.0)

	# Assert
	assert_almost_eq(h_top_left, 0.0, 0.001, "Vértice (0,0) deve ser 0.0")
	assert_almost_eq(h_top_right, 10.0, 0.001, "Vértice (1,0) deve ser 10.0")
	assert_almost_eq(h_bottom_left, 20.0, 0.001, "Vértice (0,1) deve ser 20.0")
	assert_almost_eq(h_bottom_right, 30.0, 0.001, "Vértice (1,1) deve ser 30.0")


func test_bilinear_center_interpolation() -> void:
	# Arrange: Grade 2x2 com alturas [0.0, 10.0, 20.0, 30.0], média dos 4 cantos é 15.0
	var heights = PackedFloat32Array([
		0.0, 10.0,
		20.0, 30.0
	])
	var sampler = HeightfieldSamplerClass.new(
		heights,
		2, 2,
		10.0, 10.0,
		Vector3.ZERO,
		10.0, 10.0
	)

	# Act: Centro do chunk em (0.0, 0.0)
	var h_center = sampler.get_height_at(0.0, 0.0)

	# Assert
	assert_almost_eq(h_center, 15.0, 0.001, "Interpolação no centro de 4 vértices (0, 10, 20, 30) deve ser 15.0")


func test_flat_terrain_normal_and_slope() -> void:
	# Arrange: Terreno 3x3 plano com altura constante 100.0 e origem Y = -50.0
	var heights = PackedFloat32Array([
		100.0, 100.0, 100.0,
		100.0, 100.0, 100.0,
		100.0, 100.0, 100.0
	])
	var sampler = HeightfieldSamplerClass.new(
		heights,
		3, 3,
		5.0, 5.0,
		Vector3(0.0, -50.0, 0.0),
		10.0, 10.0
	)

	# Act
	var h = sampler.get_height_at(0.0, 0.0)
	var normal = sampler.get_normal_at(0.0, 0.0)
	var slope = sampler.get_slope_ratio_at(0.0, 0.0)

	# Assert
	assert_almost_eq(h, 50.0, 0.001, "Altura somada à origem Y (-50 + 100 = 50)")
	assert_almost_eq(normal.y, 1.0, 0.01, "Normal deve apontar para cima em terreno plano")
	assert_almost_eq(slope, 0.0, 0.01, "Declive de terreno plano deve ser 0.0")


func test_ramp_terrain_slope_detection() -> void:
	# Arrange: Terreno em rampa inclinada em X: X0=0m, X1=10m em distância de 10m (declive = 1.0 ou 45 graus)
	var heights = PackedFloat32Array([
		0.0, 10.0,
		0.0, 10.0
	])
	var sampler = HeightfieldSamplerClass.new(
		heights,
		2, 2,
		10.0, 10.0,
		Vector3.ZERO,
		10.0, 10.0
	)

	# Act
	var slope = sampler.get_slope_ratio_at(0.0, 0.0)

	# Assert: declive deve ser próximo de 1.0 (45 graus)
	assert_almost_eq(slope, 1.0, 0.1, "Rampa de 10m de altura em 10m de base deve ter declive ~1.0")


func test_from_chunk_data_and_bytes() -> void:
	# Arrange
	var chunk = TerrainChunkDataClass.new("test_chunk", 1, 1, Vector3(50.0, 10.0, 50.0), 20.0, 20.0)
	chunk.grid_width = 2
	chunk.grid_depth = 2

	var raw_bytes = PackedByteArray()
	raw_bytes.resize(16)
	raw_bytes.encode_float(0, 5.0)
	raw_bytes.encode_float(4, 15.0)
	raw_bytes.encode_float(8, 25.0)
	raw_bytes.encode_float(12, 35.0)

	# Act
	var sampler = HeightfieldSamplerClass.from_chunk_data_and_bytes(chunk, raw_bytes)
	var h_top_left = sampler.get_height_at(40.0, 40.0) # Vértice (0,0) na cota do chunk

	# Assert
	assert_eq(sampler.grid_width, 2)
	assert_eq(sampler.grid_depth, 2)
	assert_almost_eq(h_top_left, 15.0, 0.001, "Origem Y (10.0) + vértice (5.0) = 15.0")
