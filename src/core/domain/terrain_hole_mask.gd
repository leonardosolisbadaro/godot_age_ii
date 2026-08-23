## @file terrain_hole_mask.gd
## @path res://src/core/domain/terrain_hole_mask.gd
##
## @description
## Entidade do Core Domain responsavel por gerenciar mascaras de visibilidade de quads
## do terreno (buracos para cavernas, dungeons e passagens subterraneas).
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
class_name TerrainHoleMask
extends RefCounted

# ==============================================================================
# ESTADO DE DOMÍNIO
# ==============================================================================

var resolution: int = 128
var _holes_set: Dictionary = { }


func _init(p_resolution: int = 128, raw_hole_indices: PackedInt32Array = PackedInt32Array()) -> void:
	resolution = p_resolution
	for idx in raw_hole_indices:
		_holes_set[idx] = true


## Retorna se o quad nas coordenadas de grade (quad_x, quad_y) e um buraco.
func is_hole(quad_x: int, quad_y: int) -> bool:
	if quad_x < 0 or quad_x >= resolution or quad_y < 0 or quad_y >= resolution:
		return false
	var key = (quad_y * resolution) + quad_x
	return _holes_set.has(key)


## Define se um quad especifico e um buraco.
func set_hole(quad_x: int, quad_y: int, is_a_hole: bool) -> void:
	if quad_x < 0 or quad_x >= resolution or quad_y < 0 or quad_y >= resolution:
		return
	var key = (quad_y * resolution) + quad_x
	if is_a_hole:
		_holes_set[key] = true
	else:
		_holes_set.erase(key)


## Retorna a quantidade total de quads marcados como buracos.
func get_hole_count() -> int:
	return _holes_set.size()
