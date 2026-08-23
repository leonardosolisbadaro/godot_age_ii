## @file kinematic_state.gd
## @path res://src/core/domain/kinematic_state.gd
##
## @description
## Entidade pura do Core Domain representando um instantâneo (snapshot) cinemático
## completo de uma entidade no espaço contínuo (tick, posição, velocidade, rotação).
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
class_name KinematicState
extends RefCounted

# ==============================================================================
# PROPRIEDADES CINEMÁTICAS
# ==============================================================================

var tick: int = 0
var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var yaw_radians: float = 0.0
var is_on_ground: bool = true


func _init(
	p_tick: int = 0,
	p_pos: Vector3 = Vector3.ZERO,
	p_vel: Vector3 = Vector3.ZERO,
	p_yaw: float = 0.0,
	p_on_ground: bool = true,
) -> void:
	tick = p_tick
	position = p_pos
	velocity = p_vel
	yaw_radians = p_yaw
	is_on_ground = p_on_ground


## Retorna uma cópia independente deste estado cinemático.
func clone() -> RefCounted:
	return (get_script() as GDScript).new(tick, position, velocity, yaw_radians, is_on_ground)


## Calcula a distância euclidiana 3D até outro estado cinemático.
func distance_to(other: RefCounted) -> float:
	if other == null or not ("position" in other):
		return 0.0
	return position.distance_to(other.position)
