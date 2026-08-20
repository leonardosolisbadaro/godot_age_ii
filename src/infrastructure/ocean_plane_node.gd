## @file ocean_plane_node.gd
## @path res://src/infrastructure/ocean_plane_node.gd
##
## @description
## Nó 3D da camada de infraestrutura que renderiza os planos de oceano e corpos
## d'água com material de shader customizado nas cotas mundiais extraídas do mapa.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends MeshInstance3D

const OceanShader = preload("res://src/infrastructure/shaders/ocean_water.gdshader")

var water_level_y: float = -290.0
var plane_size: Vector2 = Vector2(5000.0, 5000.0)
var center_pos: Vector3 = Vector3.ZERO


func _init(p_water_level: float = -290.0, p_size: Vector2 = Vector2(5000.0, 5000.0), p_center: Vector3 = Vector3.ZERO) -> void:
	water_level_y = p_water_level
	plane_size = p_size
	center_pos = p_center


func _ready() -> void:
	build_ocean_plane()


func build_ocean_plane() -> void:
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = plane_size
	plane_mesh.subdivide_width = 32
	plane_mesh.subdivide_depth = 32
	mesh = plane_mesh

	var mat = ShaderMaterial.new()
	mat.shader = OceanShader
	material_override = mat

	position = Vector3(center_pos.x, water_level_y, center_pos.z)
