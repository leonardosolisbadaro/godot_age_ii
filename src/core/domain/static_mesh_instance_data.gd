## @file static_mesh_instance_data.gd
## @path res://src/core/domain/static_mesh_instance_data.gd
##
## @description
## Entidade imutavel do Core Domain representando uma instancia individual de malha estatica
## (StaticMesh) no espaco de mundo, incluindo transformacao geometrica e propriedades de renderizacao.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
class_name StaticMeshInstanceData
extends RefCounted

# ==============================================================================
# PROPRIEDADES IMUTÁVEIS
# ==============================================================================

var mesh_name: String
var transform: Transform3D
var collision_enabled: bool
var two_sided: bool
var alpha_scissor: bool


func _init(
	p_mesh_name: String,
	p_transform: Transform3D,
	p_collision_enabled: bool = true,
	p_two_sided: bool = false,
	p_alpha_scissor: bool = false,
) -> void:
	mesh_name = p_mesh_name
	transform = p_transform
	collision_enabled = p_collision_enabled
	two_sided = p_two_sided
	alpha_scissor = p_alpha_scissor


func get_position() -> Vector3:
	return transform.origin


func get_scale() -> Vector3:
	return transform.basis.get_scale()
