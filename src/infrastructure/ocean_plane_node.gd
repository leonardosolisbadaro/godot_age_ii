## @file ocean_plane_node.gd
## @path res://src/infrastructure/ocean_plane_node.gd
##
## @description
## Nó 3D da camada de infraestrutura que renderiza os planos de oceano e corpos
## d'água com material de shader customizado nas cotas mundiais extraídas do mapa.
##
## @created 2026-08-19
## @updated 2026-08-20
##
## @author Leonardo S. Badaró
extends MeshInstance3D

const OceanShader = preload("res://src/infrastructure/shaders/ocean_water.gdshader")

# ==============================================================================
# CONSTANTES SEMÂNTICAS DE OCEANO
# ==============================================================================

## @const DEFAULT_WATER_LEVEL_Y (float)
## O que: Cota de elevação mundial padrão para o plano aquático (-320.0m).
## Porque: Nível médio do mar costeiro de Lineage II (Z = -4000 UU).
const DEFAULT_WATER_LEVEL_Y: float = -320.0

## @const DEFAULT_PLANE_SIZE (Vector2)
## O que: Dimensão horizontal da malha de plano do oceano (30000.0m x 30000.0m).
## Porque: Cobertura de horizonte contínua sem quebras visuais em todos os mapas.
const DEFAULT_PLANE_SIZE: Vector2 = Vector2(30000.0, 30000.0)

## @const DEFAULT_PLANE_SUBDIVISIONS (int)
## O que: Quantidade de subdivisões de vértices na malha plana (2x2).
## Porque: Malha ultra-otimizada de 2 triângulos para custo zero de CPU/GPU.
const DEFAULT_PLANE_SUBDIVISIONS: int = 2

## @const OCEAN_GRID_SNAP_METERS (float)
## O que: Intervalo de quantização espacial para o movimento do plano de oceano (100.0m).
## Porque: Evita tremulações (jitter) nas coordenadas UV do shader ao se movimentar.
const OCEAN_GRID_SNAP_METERS: float = 100.0

# ==============================================================================
# PROPRIEDADES DO NÓ
# ==============================================================================

var water_level_y: float = DEFAULT_WATER_LEVEL_Y
var plane_size: Vector2 = DEFAULT_PLANE_SIZE
var center_pos: Vector3 = Vector3.ZERO


func _init(
	p_water_level: float = DEFAULT_WATER_LEVEL_Y,
	p_size: Vector2 = DEFAULT_PLANE_SIZE,
	p_center: Vector3 = Vector3.ZERO,
) -> void:
	water_level_y = p_water_level
	plane_size = p_size
	center_pos = p_center


func _ready() -> void:
	build_ocean_plane()


func build_ocean_plane() -> void:
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = plane_size
	plane_mesh.subdivide_width = DEFAULT_PLANE_SUBDIVISIONS
	plane_mesh.subdivide_depth = DEFAULT_PLANE_SUBDIVISIONS
	mesh = plane_mesh

	var mat = ShaderMaterial.new()
	mat.shader = OceanShader
	material_override = mat

	update_position(center_pos)


func update_position(target_pos: Vector3) -> void:
	var snap_x = round(target_pos.x / OCEAN_GRID_SNAP_METERS) * OCEAN_GRID_SNAP_METERS
	var snap_z = round(target_pos.z / OCEAN_GRID_SNAP_METERS) * OCEAN_GRID_SNAP_METERS
	position = Vector3(snap_x, water_level_y, snap_z)

