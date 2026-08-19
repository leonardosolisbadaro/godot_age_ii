## @file sample_world_altitude_use_case.gd
## @path res://src/use_cases/sample_world_altitude_use_case.gd
##
## @description
## Caso de uso para consulta centralizada de altitude mundial Y = f(X, Z),
## localizando o chunk ativo e executando a interpolação bilinear contínua.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends RefCounted


func execute(world_x: float, world_z: float, chunks_data: Dictionary, samplers: Dictionary) -> Dictionary:
	var result = {
		"found": false,
		"altitude": 0.0,
		"chunk_name": ""
	}

	for c_name in chunks_data.keys():
		var chunk = chunks_data[c_name]
		if chunk and chunk.has_method("contains_world_point") and chunk.contains_world_point(world_x, world_z):
			var sampler = samplers.get(c_name, null)
			if sampler and sampler.has_method("get_height_at"):
				result["found"] = true
				result["altitude"] = sampler.get_height_at(world_x, world_z)
				result["chunk_name"] = c_name
				return result

	return result
