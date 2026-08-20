## @file runtime_asset_cache.gd
## @path res://src/infrastructure/runtime_asset_cache.gd
##
## @description
## Cache centralizado em memória para recursos de textura 2D e malhas 3D
## compartilhados entre múltiplos chunks e atores estáticos no mundo.
##
## @created 2026-08-20
## @updated 2026-08-20
##
## @author Leonardo S. Badaró
extends RefCounted

static var _texture_cache: Dictionary = { }
static var _mesh_cache: Dictionary = { }
static var _mutex: Mutex = Mutex.new()


static func get_or_load_texture(path: String, generate_mipmaps: bool = true) -> Texture2D:
	if path.is_empty():
		return null

	_mutex.lock()
	if _texture_cache.has(path):
		var cached: Texture2D = _texture_cache[path]
		_mutex.unlock()
		return cached
	_mutex.unlock()

	var tex: Texture2D = null
	var global_path = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path) or FileAccess.file_exists(global_path):
		var img = Image.load_from_file(global_path)
		if img and not img.is_empty():
			if generate_mipmaps:
				img.generate_mipmaps()
			tex = ImageTexture.create_from_image(img)

	if not tex and ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			tex = res

	if tex:
		_mutex.lock()
		_texture_cache[path] = tex
		_mutex.unlock()

	return tex


static func get_or_load_mesh(mesh_path: String) -> Mesh:
	if mesh_path.is_empty():
		return null

	_mutex.lock()
	if _mesh_cache.has(mesh_path):
		var cached_mesh: Mesh = _mesh_cache[mesh_path]
		_mutex.unlock()
		return cached_mesh
	_mutex.unlock()

	var mesh: Mesh = null

	if ResourceLoader.exists(mesh_path):
		var scene_res = load(mesh_path)
		if scene_res is PackedScene:
			var temp_node = scene_res.instantiate()
			mesh = _extract_mesh_from_node(temp_node)
			temp_node.free()
		elif scene_res is Mesh:
			mesh = scene_res

	if not mesh and FileAccess.file_exists(mesh_path):
		var gltf_doc = GLTFDocument.new()
		var gltf_state = GLTFState.new()
		var err = gltf_doc.append_from_file(mesh_path, gltf_state)
		if err == OK:
			var temp_node = gltf_doc.generate_scene(gltf_state)
			if temp_node:
				mesh = _extract_mesh_from_node(temp_node)
				temp_node.free()

	if mesh:
		_mutex.lock()
		_mesh_cache[mesh_path] = mesh
		_mutex.unlock()

	return mesh


static func _extract_mesh_from_node(node: Node) -> Mesh:
	if not node:
		return null
	if node is MeshInstance3D and node.mesh:
		return node.mesh
	for child in node.get_children():
		var m = _extract_mesh_from_node(child)
		if m:
			return m
	return null


static func clear() -> void:
	_mutex.lock()
	_texture_cache.clear()
	_mesh_cache.clear()
	_mutex.unlock()


static func get_texture_count() -> int:
	_mutex.lock()
	var count = _texture_cache.size()
	_mutex.unlock()
	return count


static func get_mesh_count() -> int:
	_mutex.lock()
	var count = _mesh_cache.size()
	_mutex.unlock()
	return count
