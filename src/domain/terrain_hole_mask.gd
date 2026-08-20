## @file terrain_hole_mask.gd
## @path res://src/domain/terrain_hole_mask.gd
##
## @description
## Entidade de domínio pura para validação de quads perfurados/invisíveis do terreno
## (QuadVisibilityBitmap), permitindo a travessia de cavernas, minas e masmorras.
##
## @created 2026-08-19
## @updated 2026-08-20
##
## @author Leonardo S. Badaró
extends RefCounted

const TerrainChunkDataClass = preload("res://src/domain/terrain_chunk_data.gd")

# ==============================================================================
# CONSTANTES SEMÂNTICAS DE BITMASK
# ==============================================================================

## @const BITS_PER_BYTE_SHIFT (int)
## O que: Shift binário para indexação por byte em máscara de bits (divisão por 8 via >> 3).
## Porque: Cada byte armazena 8 quads de visibilidade.
const BITS_PER_BYTE_SHIFT: int = 3

## @const BIT_MASK_7 (int)
## O que: Máscara bit a bit para obter o índice de bit [0..7] dentro do byte (operador & 7).
## Porque: Indexação direta e eficiente.
const BIT_MASK_7: int = 7

## @const EPSILON_DIMENSION (float)
## O que: Margem de estabilidade numérica contra divisão por zero (0.001).
## Porque: Garante que dimensões nulas não causem exceção de ponto flutuante.
const EPSILON_DIMENSION: float = 0.001

## @const NORM_MAX_BOUND (float)
## O que: Limite superior da coordenada normalizada antes do arredondamento (0.9999).
## Porque: Previne que o índice máximo transborde a largura da grade de quads.
const NORM_MAX_BOUND: float = 0.9999

# ==============================================================================
# PROPRIEDADES DA ENTIDADE
# ==============================================================================

var hole_bytes: PackedByteArray
var quads_x: int = 0
var quads_z: int = 0


func _init(
	p_hole_bytes: PackedByteArray = PackedByteArray(),
	p_quads_x: int = 0,
	p_quads_z: int = 0,
) -> void:
	hole_bytes = p_hole_bytes
	quads_x = p_quads_x
	quads_z = p_quads_z


func is_hole_at(qx: int, qz: int) -> bool:
	if hole_bytes.is_empty() or qx < 0 or qx >= quads_x or qz < 0 or qz >= quads_z:
		return false

	var index = qz * quads_x + qx
	# Se a máscara for 1 byte por quad (0 = visível, 1 = buraco)
	if hole_bytes.size() == (quads_x * quads_z):
		return hole_bytes[index] != 0

	# Se for bitmask compactado (1 bit por quad)
	var byte_idx = index >> BITS_PER_BYTE_SHIFT
	var bit_idx = index & BIT_MASK_7
	if byte_idx < hole_bytes.size():
		return (hole_bytes[byte_idx] & (1 << bit_idx)) != 0

	return false


func set_hole_at(qx: int, qz: int, is_hole: bool) -> void:
	if qx < 0 or qx >= quads_x or qz < 0 or qz >= quads_z:
		return

	var total_quads = quads_x * quads_z
	if hole_bytes.size() != total_quads:
		hole_bytes.resize(total_quads)

	var index = qz * quads_x + qx
	hole_bytes[index] = 1 if is_hole else 0


func is_hole_at_world(world_x: float, world_z: float, chunk_data: TerrainChunkDataClass) -> bool:
	if not chunk_data or quads_x <= 0 or quads_z <= 0:
		return false

	var local = chunk_data.get_local_coordinates(world_x, world_z)
	var norm_x = clampf(
		local.x / maxf(chunk_data.total_width_meters, EPSILON_DIMENSION),
		0.0,
		NORM_MAX_BOUND,
	)
	var norm_z = clampf(
		local.y / maxf(chunk_data.total_depth_meters, EPSILON_DIMENSION),
		0.0,
		NORM_MAX_BOUND,
	)

	var qx = int(norm_x * float(quads_x))
	var qz = int(norm_z * float(quads_z))

	return is_hole_at(qx, qz)
