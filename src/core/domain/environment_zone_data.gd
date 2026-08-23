## @file environment_zone_data.gd
## @path res://src/core/domain/environment_zone_data.gd
##
## @description
## Entidade imutavel do Core Domain contendo parametros puros de iluminacao,
## cor solar, neblina e atmosfera de uma zona ambiental de Lineage II.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
class_name EnvironmentZoneData
extends RefCounted

# ==============================================================================
# PROPRIEDADES DE ILUMINAÇÃO E ATMOSFERA
# ==============================================================================

var sun_color: Color
var ambient_color: Color
var fog_color: Color
var fog_density: float
var sun_direction: Vector3


func _init(
	p_sun_color: Color = Color(1.0, 0.95, 0.85),
	p_ambient_color: Color = Color(0.25, 0.30, 0.40),
	p_fog_color: Color = Color(0.60, 0.70, 0.80),
	p_fog_density: float = 0.001,
	p_sun_direction: Vector3 = Vector3(-0.5, -0.8, -0.3).normalized(),
) -> void:
	sun_color = p_sun_color
	ambient_color = p_ambient_color
	fog_color = p_fog_color
	fog_density = p_fog_density
	sun_direction = p_sun_direction.normalized()
