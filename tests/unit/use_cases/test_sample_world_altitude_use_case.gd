## @file test_sample_world_altitude_use_case.gd
## @path res://tests/unit/use_cases/test_sample_world_altitude_use_case.gd
##
## @description
## Testes unitários AAA para SampleWorldAltitudeUseCase.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends GutTest

const SampleWorldAltitudeUseCaseClass = preload("res://src/use_cases/sample_world_altitude_use_case.gd")
const TerrainChunkDataClass = preload("res://src/domain/terrain_chunk_data.gd")
const HeightfieldSamplerClass = preload("res://src/domain/heightfield_sampler.gd")


func test_sample_world_altitude_finds_correct_chunk() -> void:
	# Arrange
	var chunk1 = TerrainChunkDataClass.new("16_24", 16, 24, Vector3(0.0, 0.0, 0.0), 100.0, 100.0)
	var sampler1 = HeightfieldSamplerClass.new(PackedFloat32Array([10.0, 10.0, 10.0, 10.0]), 2, 2, 100.0, 100.0, Vector3.ZERO, 100.0, 100.0)

	var chunk2 = TerrainChunkDataClass.new("16_25", 16, 25, Vector3(100.0, 0.0, 0.0), 100.0, 100.0)
	var sampler2 = HeightfieldSamplerClass.new(PackedFloat32Array([50.0, 50.0, 50.0, 50.0]), 2, 2, 100.0, 100.0, Vector3(100.0, 0.0, 0.0), 100.0, 100.0)

	var chunks = { "16_24": chunk1, "16_25": chunk2 }
	var samplers = { "16_24": sampler1, "16_25": sampler2 }

	var use_case = SampleWorldAltitudeUseCaseClass.new()

	# Act
	var res1 = use_case.execute(10.0, 10.0, chunks, samplers)
	var res2 = use_case.execute(110.0, 10.0, chunks, samplers)
	var res_out = use_case.execute(500.0, 500.0, chunks, samplers)

	# Assert
	assert_true(res1["found"])
	assert_eq(res1["chunk_name"], "16_24")
	assert_almost_eq(res1["altitude"], 10.0, 0.001)

	assert_true(res2["found"])
	assert_eq(res2["chunk_name"], "16_25")
	assert_almost_eq(res2["altitude"], 50.0, 0.001)

	assert_false(res_out["found"])
