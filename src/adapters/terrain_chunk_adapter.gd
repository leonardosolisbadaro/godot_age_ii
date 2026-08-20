## @file terrain_chunk_adapter.gd
## @path res://src/adapters/terrain_chunk_adapter.gd
##
## @description
## Adaptador de interface para instanciação e configuração de nós visuais de terreno
## (MeshInstance3D) carregando a malha compilada e texturas do chunk.
##
## @created 2026-08-19
## @updated 2026-08-20
##
## @author Leonardo S. Badaró
extends RefCounted


func get_visual_glb_path(chunk_name: String, base_path: String = "res://assets/maps") -> String:
	return "%s/%s/client/%s_visual.glb" % [base_path, chunk_name, chunk_name]


func load_visual_mesh_node(chunk_name: String, base_path: String = "res://assets/maps") -> Node3D:
	var path = get_visual_glb_path(chunk_name, base_path)
	if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
		return null

	if ResourceLoader.exists(path):
		var scene_res = load(path)
		if scene_res and scene_res is PackedScene:
			return scene_res.instantiate() as Node3D

	# Fallback nativo via GLTFDocument para carregamento direto do binário .glb
	var gltf_doc = GLTFDocument.new()
	var gltf_state = GLTFState.new()
	var err = gltf_doc.append_from_file(path, gltf_state)
	if err == OK:
		var scene = gltf_doc.generate_scene(gltf_state)
		return scene as Node3D

	return null
