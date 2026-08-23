## @file test_sample_terrain_altitude_use_case.gd
## @path res://tests/core/test_sample_terrain_altitude_use_case.gd
##
## @description
## Testes unitarios GUT AAA do SampleTerrainAltitudeUseCase.
## Valida amostragem de vertices exatos, interpolacao bilinear intermediaria e calculo de normais.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
extends GutTest

const SampleTerrainAltitudeUseCaseClass = preload(
	"res://src/core/use_cases/sample_terrain_altitude_use_case.gd"
)


func test_bilinear_interpolation_corner_and_center() -> void:
	# Arrange (Grid 2x2: (0,0)=0, (1,0)=10, (0,1)=20, (1,1)=30)
	var heightfield = PackedFloat32Array([
			0.0,
			10.0,
			20.0,
			30.0,
		])
	var res = 2
	var size = 100.0

	# Act - Amostra nos 4 cantos
	var h_nw = SampleTerrainAltitudeUseCaseClass.sample_altitude(0.0, 0.0, heightfield, res, size)
	var h_ne = SampleTerrainAltitudeUseCaseClass.sample_altitude(100.0, 0.0, heightfield, res, size)
	var h_sw = SampleTerrainAltitudeUseCaseClass.sample_altitude(0.0, 100.0, heightfield, res, size)
	var h_se = SampleTerrainAltitudeUseCaseClass.sample_altitude(
		100.0,
		100.0,
		heightfield,
		res,
		size,
	)

	# Act - Amostra no centro exato (50, 50) -> media de (0+10+20+30)/4 = 15.0
	var h_center = SampleTerrainAltitudeUseCaseClass.sample_altitude(
		50.0,
		50.0,
		heightfield,
		res,
		size,
	)

	# Assert
	assert_almost_eq(h_nw, 0.0, 0.001, "Canto NW deve ser 0.0.")
	assert_almost_eq(h_ne, 10.0, 0.001, "Canto NE deve ser 10.0.")
	assert_almost_eq(h_sw, 20.0, 0.001, "Canto SW deve ser 20.0.")
	assert_almost_eq(h_se, 30.0, 0.001, "Canto SE deve ser 30.0.")
	assert_almost_eq(h_center, 15.0, 0.001, "Centro exato deve ser 15.0 por interpolacao bilinear.")


func test_sample_normal_flat_terrain() -> void:
	# Arrange (Grid plano com altura constante 5.0)
	var heightfield = PackedFloat32Array([
			5.0,
			5.0,
			5.0,
			5.0,
		])
	var res = 2
	var size = 100.0

	# Act
	var normal = SampleTerrainAltitudeUseCaseClass.sample_normal(50.0, 50.0, heightfield, res, size)

	# Assert
	assert_almost_eq(normal.x, 0.0, 0.001, "Normal plana X=0.")
	assert_almost_eq(normal.y, 1.0, 0.001, "Normal plana Y=1 (para cima).")
	assert_almost_eq(normal.z, 0.0, 0.001, "Normal plana Z=0.")
