## @file radius_gizmo_node.gd
## @path res://src/infrastructure/radius_gizmo_node.gd
##
## @description
## Nó de depuração visual 3D que renderiza um anel/círculo radiante no solo
## para indicar o raio de busca e inspeção espacial ao redor do jogador.
##
## @created 2026-08-21
## @updated 2026-08-21
##
## @author Leonardo S. Badaró
extends Node3D

const DEFAULT_RADIUS: float = 40.0
const MIN_RADIUS: float = 5.0
const MAX_RADIUS: float = 100.0
const SEGMENTS: int = 64

var radius: float = DEFAULT_RADIUS:
	set(val):
		var clamped = clampf(val, MIN_RADIUS, MAX_RADIUS)
		if not is_equal_approx(radius, clamped):
			radius = clamped
			_redraw_circle()

var _mesh_instance: MeshInstance3D
var _immediate_mesh: ImmediateMesh
var _line_material: StandardMaterial3D


func _init(p_radius: float = DEFAULT_RADIUS) -> void:
	name = "RadiusGizmoNode"
	radius = p_radius
	_setup_nodes()
	_redraw_circle()


func _setup_nodes() -> void:
	_immediate_mesh = ImmediateMesh.new()
	_line_material = StandardMaterial3D.new()
	_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_material.albedo_color = Color(0.1, 0.85, 1.0, 0.9) # Ciano brilhante
	_line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_line_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_line_material.no_depth_test = true
	_line_material.render_priority = 10

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "GizmoMeshInstance"
	_mesh_instance.mesh = _immediate_mesh
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)


func _redraw_circle() -> void:
	if not _immediate_mesh or not _line_material:
		return

	_immediate_mesh.clear_surfaces()
	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _line_material)

	var step = (PI * 2.0) / float(SEGMENTS)
	for i in range(SEGMENTS):
		var a1 = float(i) * step
		var a2 = float(i + 1) * step
		var p1 = Vector3(cos(a1) * radius, 0.1, sin(a1) * radius)
		var p2 = Vector3(cos(a2) * radius, 0.1, sin(a2) * radius)
		_immediate_mesh.surface_add_vertex(p1)
		_immediate_mesh.surface_add_vertex(p2)

	# Marcas cardeais (Ticks) a cada 90 graus
	for i in range(4):
		var a = float(i) * (PI * 0.5)
		var inner_p = Vector3(cos(a) * (radius - 1.5), 0.1, sin(a) * (radius - 1.5))
		var outer_p = Vector3(cos(a) * (radius + 1.5), 0.1, sin(a) * (radius + 1.5))
		_immediate_mesh.surface_add_vertex(inner_p)
		_immediate_mesh.surface_add_vertex(outer_p)

	_immediate_mesh.surface_end()


func set_radius(p_radius: float) -> void:
	radius = p_radius


func get_radius() -> float:
	return radius


func set_center_position(pos: Vector3) -> void:
	global_position = pos


func set_gizmo_visible(is_vis: bool) -> void:
	visible = is_vis
