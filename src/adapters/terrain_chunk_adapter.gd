## @file terrain_chunk_adapter.gd
## @path res://src/adapters/terrain_chunk_adapter.gd
##
## @description
## Adaptador de interface para instanciação e configuração de nós visuais de terreno
## (MeshInstance3D) carregando a malha compilada e texturas do chunk.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends RefCounted


func get_visual_glb_path(chunk_name: String, base_path: String = "res://assets/maps") -> String:
	return "%s/%s/client/%s_visual.glb" % [base_path, chunk_name, chunk_name]


func load_visual_mesh_node(chunk_name: String, base_path: String = "res://assets/maps") -> Node3D:
	var path = get_visual_glb_path(chunk_name, base_path)
	if not ResourceLoader.exists(path):
		return null

	var scene_res = load(path)
	if scene_res and scene_res is PackedScene:
		var instance = scene_res.instantiate()
		return instance as Node3D

	return null
