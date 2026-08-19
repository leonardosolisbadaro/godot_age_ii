## @file test_terrain_hole_mask.gd
## @path res://tests/unit/domain/test_terrain_hole_mask.gd
##
## @description
## Testes unitários AAA para a entidade de domínio TerrainHoleMask.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends GutTest

const TerrainHoleMaskClass = preload("res://src/domain/terrain_hole_mask.gd")
const TerrainChunkDataClass = preload("res://src/domain/terrain_chunk_data.gd")


func test_hole_at_grid_and_mutation() -> void:
	# Arrange: Grade 4x4 quads inicialmente sem buracos
	var mask = TerrainHoleMaskClass.new(PackedByteArray(), 4, 4)

	# Act: Perfura o quad central (2, 2)
	mask.set_hole_at(2, 2, true)

	# Assert
	assert_true(mask.is_hole_at(2, 2), "Quad (2,2) deve ser identificado como buraco")
	assert_false(mask.is_hole_at(0, 0), "Quad (0,0) deve ser terreno sólido")
	assert_false(mask.is_hole_at(2, 1), "Quad vizinho (2,1) deve ser sólido")
	assert_false(mask.is_hole_at(-1, 0), "Fora do grid deve retornar falso")
	assert_false(mask.is_hole_at(5, 5), "Fora do grid deve retornar falso")


func test_hole_at_world_coordinates() -> void:
	# Arrange: Chunk centralizado em (0, 0, 0) de tamanho 100x100m [-50 .. +50]
	# Grid de 2x2 quads (cada quad mede 50x50m)
	# Quad (0,0): X[-50..0], Z[-50..0]
	# Quad (1,1): X[0..50],  Z[0..50]
	var chunk = TerrainChunkDataClass.new("cave_chunk", 0, 0, Vector3.ZERO, 100.0, 100.0)
	var mask = TerrainHoleMaskClass.new(PackedByteArray(), 2, 2)

	# Act: Cria entrada da caverna no canto inferior direito Quad (1, 1)
	mask.set_hole_at(1, 1, true)

	# Assert
	assert_true(mask.is_hole_at_world(25.0, 25.0, chunk), "Ponto no centro do Quad (1,1) deve ser buraco")
	assert_false(mask.is_hole_at_world(-25.0, -25.0, chunk), "Ponto no Quad (0,0) deve ser solo sólido")
	assert_false(mask.is_hole_at_world(-25.0, 25.0, chunk), "Ponto no Quad (0,1) deve ser solo sólido")


func test_bitmask_byte_array_support() -> void:
	# Arrange: Bitmask compactado de 8 quads (1 byte). 
	# Bits: 00000101 (quinto bit = quad 2, primeiro bit = quad 0)
	var byte_val = 0b00000101 # Quads 0 e 2 são buracos
	var bytes = PackedByteArray([byte_val])
	var mask = TerrainHoleMaskClass.new(bytes, 8, 1)

	# Assert
	assert_true(mask.is_hole_at(0, 0), "Quad 0 deve ser buraco")
	assert_false(mask.is_hole_at(1, 0), "Quad 1 deve ser sólido")
	assert_true(mask.is_hole_at(2, 0), "Quad 2 deve ser buraco")
	assert_false(mask.is_hole_at(3, 0), "Quad 3 deve ser sólido")
