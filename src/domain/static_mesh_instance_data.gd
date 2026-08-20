## @file static_mesh_instance_data.gd
## @path res://src/domain/static_mesh_instance_data.gd
##
## @description
## Entidade de domínio pura representando a instância espacial de um objeto/ator
## estático de cenário no mundo (malha, transformação métrica e AABB de colisão).
##
## @created 2026-08-19
## @updated 2026-08-20
##
## @author Leonardo S. Badaró
extends RefCounted

# ==============================================================================
# CONSTANTES SEMÂNTICAS DE INSTÂNCIA
# ==============================================================================

## @const DEFAULT_AABB_POS (Vector3)
## O que: Posição mínima padrão da caixa delimitadora local (X=-1.0m, Y=0.0m, Z=-1.0m).
## Porque: Centrada na base do objeto.
const DEFAULT_AABB_POS: Vector3 = Vector3(-1.0, 0.0, -1.0)

## @const DEFAULT_AABB_SIZE (Vector3)
## O que: Dimensão padrão da caixa delimitadora local (2.0m x 2.0m x 2.0m).
## Porque: Volume unitário básico de ator.
const DEFAULT_AABB_SIZE: Vector3 = Vector3(2.0, 2.0, 2.0)

# ==============================================================================
# PROPRIEDADES DA ENTIDADE
# ==============================================================================

var actor_name: String = ""
var mesh_name: String = ""
var mesh_resource_path: String = ""
var position: Vector3 = Vector3.ZERO
var rotation_radians: Vector3 = Vector3.ZERO
var scale: Vector3 = Vector3.ONE
var base_aabb: AABB = AABB(DEFAULT_AABB_POS, DEFAULT_AABB_SIZE)
var properties: Dictionary = { }


func _init(
	p_actor_name: String = "",
	p_mesh_name: String = "",
	p_mesh_path: String = "",
	p_pos: Vector3 = Vector3.ZERO,
	p_rot: Vector3 = Vector3.ZERO,
	p_scale: Vector3 = Vector3.ONE,
	p_aabb: AABB = AABB(DEFAULT_AABB_POS, DEFAULT_AABB_SIZE),
) -> void:
	actor_name = p_actor_name
	mesh_name = p_mesh_name
	mesh_resource_path = p_mesh_path
	position = p_pos
	rotation_radians = p_rot
	scale = p_scale
	base_aabb = p_aabb


func from_actor_dictionary(dict: Dictionary) -> void:
	actor_name = str(dict.get("actor_name", actor_name))
	mesh_name = str(dict.get("mesh_name", mesh_name))
	mesh_resource_path = str(dict.get("mesh_resource_path", mesh_resource_path))

	# Suporte a mesh_ref aninhado
	var mesh_ref = dict.get("mesh_ref")
	if mesh_ref is Dictionary and not mesh_ref.is_empty():
		mesh_name = str(mesh_ref.get("object_name", mesh_name))
		var pkg = str(mesh_ref.get("package", ""))
		if not pkg.is_empty() and not mesh_name.is_empty():
			mesh_resource_path = "res://assets/models/%s/%s.glb" % [pkg.to_lower(), mesh_name]

	# Suporte a transform aninhado ou plano
	var t_dict = dict.get("transform")
	if not (t_dict is Dictionary):
		t_dict = dict

	var pos_arr = t_dict.get("position_meters")
	if pos_arr is Array and pos_arr.size() >= 3:
		position = Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))

	var rot_arr = t_dict.get("rotation_euler_rad")
	if not (rot_arr is Array):
		rot_arr = t_dict.get("rotation_radians")
	if rot_arr is Array and rot_arr.size() >= 3:
		rotation_radians = Vector3(float(rot_arr[0]), float(rot_arr[1]), float(rot_arr[2]))

	var scl_arr = t_dict.get("scale")
	if scl_arr is Array and scl_arr.size() >= 3:
		scale = Vector3(float(scl_arr[0]), float(scl_arr[1]), float(scl_arr[2]))

	var aabb_dict = dict.get("base_aabb", { })
	if not aabb_dict.is_empty():
		var pos_a = aabb_dict.get(
			"position",
			[DEFAULT_AABB_POS.x, DEFAULT_AABB_POS.y, DEFAULT_AABB_POS.z],
		)
		var size_a = aabb_dict.get(
			"size",
			[DEFAULT_AABB_SIZE.x, DEFAULT_AABB_SIZE.y, DEFAULT_AABB_SIZE.z],
		)
		base_aabb = AABB(
			Vector3(float(pos_a[0]), float(pos_a[1]), float(pos_a[2])),
			Vector3(float(size_a[0]), float(size_a[1]), float(size_a[2])),
		)


func get_transform() -> Transform3D:
	var b = Basis.from_euler(rotation_radians)
	b = b.scaled(scale)
	return Transform3D(b, position)


func get_world_aabb() -> AABB:
	var scaled_pos = base_aabb.position * scale
	var scaled_size = base_aabb.size * scale
	return AABB(position + scaled_pos, scaled_size).abs()


func intersects_point(point: Vector3) -> bool:
	return get_world_aabb().has_point(point)
