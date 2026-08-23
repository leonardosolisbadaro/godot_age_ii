## @file water_volume_data.gd
## @path res://src/core/domain/water_volume_data.gd
##
## @description
## Entidade do Core Domain representando volumes e corpos d'agua de Lineage II
## (oceanos, rios, lagos, fossos e piscinas), incluindo cotas de superficie e teste de submersao.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
class_name WaterVolumeData
extends RefCounted

# ==============================================================================
# PROPRIEDADES DE DOMÍNIO
# ==============================================================================

var volume_id: String
var surface_level_y: float
var bounds_aabb: AABB
var water_type: String


func _init(
	p_id: String,
	p_surface_y: float,
	p_bounds: AABB,
	p_type: String = "LAKE",
) -> void:
	volume_id = p_id
	surface_level_y = p_surface_y
	bounds_aabb = p_bounds
	water_type = p_type


## Verifica se uma coordenada 3D em metros esta horizontalmente dentro dos limites deste corpo d'agua.
func contains_horizontal_point(point: Vector3) -> bool:
	return (
		point.x >= bounds_aabb.position.x and point.x <= bounds_aabb.end.x
		and point.z >= bounds_aabb.position.z and point.z <= bounds_aabb.end.z
	)


## Verifica se um ponto 3D esta submerso (dentro dos limites horizontais e abaixo da cota de superficie).
func is_submerged(point: Vector3) -> bool:
	if not contains_horizontal_point(point):
		return false
	return point.y <= surface_level_y and point.y >= bounds_aabb.position.y
