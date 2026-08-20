## @file mesh_selection_highlighter.gd
## @path res://src/infrastructure/mesh_selection_highlighter.gd
##
## @description
## Nó 3D de depuração visual que desenha uma borda bem definida envolvendo
## 100% da malha poligonal selecionada (Inverted Hull Outline) e caixa delimitadora (AABB).
##
## @created 2026-08-20
## @updated 2026-08-20
##
## @author Leonardo S. Badaró
extends Node3D

# ==============================================================================
# CONSTANTES SEMÂNTICAS DE DESTAQUE VISUAL
# ==============================================================================

## @const DEFAULT_HULL_GROW_AMOUNT (float)
## O que: Expansão da borda invertida da malha em metros (0.35m = 35cm).
## Porque: Silhueta nítida visível à distância.
const DEFAULT_HULL_GROW_AMOUNT: float = 0.35

## @const DEFAULT_HULL_COLOR (Color)
## O que: Cor ciano vibrante de alto contraste da silhueta (RGBA 0.0, 1.0, 0.9, 0.95).
## Porque: Excelente visibilidade sobre folhagens e terrenos.
const DEFAULT_HULL_COLOR: Color = Color(0.0, 1.0, 0.9, 0.95)

## @const DEFAULT_LINE_COLOR (Color)
## O que: Cor amarela elétrica do wireframe de AABB (RGBA 1.0, 0.9, 0.1, 0.9).
## Porque: Destaca o volume cúbico envolvente.
const DEFAULT_LINE_COLOR: Color = Color(1.0, 0.9, 0.1, 0.9)

## @const MIN_AABB_SIZE_SQ (float)
## O que: Tamanho quadrático mínimo de AABB para renderização de arestas (0.001).
## Porque: Previne desenho de caixas degeneradas com volume zero.
const MIN_AABB_SIZE_SQ: float = 0.001

# ==============================================================================
# PROPRIEDADES DO NÓ
# ==============================================================================

var _hull_mesh_instance: MeshInstance3D
var _box_mesh_instance: MeshInstance3D
var _immediate_mesh: ImmediateMesh
var _line_material: StandardMaterial3D
var _hull_material: StandardMaterial3D


func _init() -> void:
	# 1. Malha de Contorno Poligonal (Inverted Hull Outline)
	_hull_mesh_instance = MeshInstance3D.new()
	_hull_mesh_instance.name = "HullOutlineMesh"

	_hull_material = StandardMaterial3D.new()
	_hull_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hull_material.albedo_color = DEFAULT_HULL_COLOR
	_hull_material.cull_mode = BaseMaterial3D.CULL_FRONT
	_hull_material.grow = true
	_hull_material.grow_amount = DEFAULT_HULL_GROW_AMOUNT
	_hull_material.no_depth_test = true
	_hull_mesh_instance.material_override = _hull_material
	add_child(_hull_mesh_instance)

	# 2. Caixa 3D Delimitadora (AABB Wireframe)
	_immediate_mesh = ImmediateMesh.new()
	_box_mesh_instance = MeshInstance3D.new()
	_box_mesh_instance.name = "BoxOutlineMesh"
	_box_mesh_instance.mesh = _immediate_mesh

	_line_material = StandardMaterial3D.new()
	_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_material.albedo_color = DEFAULT_LINE_COLOR
	_line_material.no_depth_test = true
	_line_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_box_mesh_instance.material_override = _line_material
	add_child(_box_mesh_instance)

	visible = false


func highlight_mesh_and_aabb(mesh: Mesh, xform: Transform3D, aabb: AABB) -> void:
	visible = true

	# Aplica silhueta na malha real
	if mesh:
		_hull_mesh_instance.mesh = mesh
		_hull_mesh_instance.global_transform = xform
		_hull_mesh_instance.visible = true
	else:
		_hull_mesh_instance.visible = false

	# Desenha caixa delimitadora exata
	_draw_box(aabb.abs())


func highlight_aabb(aabb: AABB) -> void:
	visible = true
	_hull_mesh_instance.visible = false
	_draw_box(aabb.abs())


func _draw_box(safe_aabb: AABB) -> void:
	if safe_aabb.size.length_squared() < MIN_AABB_SIZE_SQ:
		clear_highlight()
		return

	_immediate_mesh.clear_surfaces()
	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _line_material)

	var p0 = safe_aabb.position
	var p1 = safe_aabb.position + Vector3(safe_aabb.size.x, 0.0, 0.0)
	var p2 = safe_aabb.position + Vector3(safe_aabb.size.x, 0.0, safe_aabb.size.z)
	var p3 = safe_aabb.position + Vector3(0.0, 0.0, safe_aabb.size.z)
	var p4 = p0 + Vector3(0.0, safe_aabb.size.y, 0.0)
	var p5 = p1 + Vector3(0.0, safe_aabb.size.y, 0.0)
	var p6 = p2 + Vector3(0.0, safe_aabb.size.y, 0.0)
	var p7 = p3 + Vector3(0.0, safe_aabb.size.y, 0.0)

	# 12 Arestas da Caixa 3D
	_add_line(p0, p1)
	_add_line(p1, p2)
	_add_line(p2, p3)
	_add_line(p3, p0)
	_add_line(p4, p5)
	_add_line(p5, p6)
	_add_line(p6, p7)
	_add_line(p7, p4)
	_add_line(p0, p4)
	_add_line(p1, p5)
	_add_line(p2, p6)
	_add_line(p3, p7)

	_immediate_mesh.surface_end()


func _add_line(a: Vector3, b: Vector3) -> void:
	_immediate_mesh.surface_add_vertex(a)
	_immediate_mesh.surface_add_vertex(b)


func clear_highlight() -> void:
	visible = false
	_immediate_mesh.clear_surfaces()
	_hull_mesh_instance.mesh = null
