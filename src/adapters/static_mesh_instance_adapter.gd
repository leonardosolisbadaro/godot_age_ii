## @file static_mesh_instance_adapter.gd
## @path res://src/adapters/static_mesh_instance_adapter.gd
##
## @description
## Adaptador de interface que converte instâncias de StaticMeshInstanceData em nós
## otimizados de MultiMeshInstance3D para renderização em lote de alta performance.
##
## @created 2026-08-19
## @updated 2026-08-20
##
## @author Leonardo S. Badaró
extends RefCounted

const StaticMeshInstanceDataClass = preload("res://src/domain/static_mesh_instance_data.gd")


func parse_actor_dictionaries(actors_raw: Array) -> Array:
	var result: Array = []
	for item in actors_raw:
		if item is Dictionary:
			var instance_data = StaticMeshInstanceDataClass.new()
			instance_data.from_actor_dictionary(item)
			result.append(instance_data)
	return result


func group_by_mesh_path(instances: Array) -> Dictionary:
	var groups: Dictionary = { }
	for inst in instances:
		if not (inst is StaticMeshInstanceDataClass):
			continue
		var path = inst.mesh_resource_path
		if not groups.has(path):
			groups[path] = []
		groups[path].append(inst)
	return groups


func create_multimesh_instance(mesh: Mesh, instances: Array) -> MultiMeshInstance3D:
	if not mesh or instances.is_empty():
		return null

	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = instances.size()
	multimesh.mesh = mesh

	for i in range(instances.size()):
		var inst = instances[i]
		if inst and inst.has_method("get_transform"):
			multimesh.set_instance_transform(i, inst.get_transform())

	var mm_node = MultiMeshInstance3D.new()
	mm_node.multimesh = multimesh
	return mm_node
