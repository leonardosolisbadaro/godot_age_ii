## @file sample_world_altitude_use_case.gd
## @path res://src/use_cases/sample_world_altitude_use_case.gd
##
## @description
## Caso de uso para consultar e interpolar a altitude exata do solo em coordenadas
## mundiais (X, Z), identificando dinamicamente o chunk e amostrador correspondente.
##
## @created 2026-08-19
## @updated 2026-08-20
##
## @author Leonardo S. Badaró
extends RefCounted


func execute(world_x: float, world_z: float, chunks_data: Dictionary, samplers: Dictionary) -> Dictionary:
	for c_name in chunks_data.keys():
		var chunk = chunks_data[c_name]
		if (
			chunk and chunk.has_method("contains_world_point")
			and chunk.contains_world_point(world_x, world_z)
		):
			var sampler = samplers.get(c_name, null)
			if sampler and sampler.has_method("get_height_at"):
				var alt = sampler.get_height_at(world_x, world_z)
				return {
					"found": true,
					"chunk_name": c_name,
					"altitude": alt,
				}

	return {
		"found": false,
		"chunk_name": "",
		"altitude": 0.0,
	}
