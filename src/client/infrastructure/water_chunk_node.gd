## @file water_chunk_node.gd
## @path res://src/client/infrastructure/water_chunk_node.gd
##
## @description
## Nó 3D da camada de apresentação/infraestrutura que instancia os planos de malha
## de água e aplica o shader de reflexo e ondas ocean_water.gdshader nas cotas de cada volume.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
class_name WaterChunkNode
extends Node3D

# ==============================================================================
# DEPENDÊNCIAS PRELOAD
# ==============================================================================

const OceanShader = preload("res://src/client/infrastructure/shaders/ocean_water.gdshader")
const ChunkResourceAdapterClass = preload("res://src/client/adapters/chunk_resource_adapter.gd")
const WaterVolumeDataClass = preload("res://src/core/domain/water_volume_data.gd")

# ==============================================================================
# PROPRIEDADES
# ==============================================================================

var chunk_name: String = ""
var base_maps_path: String = "res://assets/maps"
var _is_built: bool = false


func _init(p_chunk_name: String = "", p_base_path: String = "res://assets/maps") -> void:
	chunk_name = p_chunk_name
	base_maps_path = p_base_path


func _ready() -> void:
	if not chunk_name.is_empty() and not _is_built:
		build_water_nodes()


## Carrega os volumes de água do chunk e instancia os planos de malha correspondentes.
func build_water_nodes() -> void:
	if _is_built or chunk_name.is_empty():
		return
	_is_built = true

	var volumes = ChunkResourceAdapterClass.load_water_volumes(chunk_name, base_maps_path)
	for vol in volumes:
		var plane_mesh = PlaneMesh.new()
		plane_mesh.size = Vector2(vol.bounds_aabb.size.x, vol.bounds_aabb.size.z)

		var mat = ShaderMaterial.new()
		mat.shader = OceanShader

		var mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "WaterPlane_%s" % vol.volume_id
		mesh_instance.mesh = plane_mesh
		mesh_instance.material_override = mat

		var center_x = vol.bounds_aabb.position.x + (vol.bounds_aabb.size.x * 0.5)
		var center_z = vol.bounds_aabb.position.z + (vol.bounds_aabb.size.z * 0.5)
		mesh_instance.position = Vector3(center_x, vol.surface_level_y, center_z)

		add_child(mesh_instance)
