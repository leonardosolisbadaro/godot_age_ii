## @file runtime_asset_cache.gd
## @path res://src/infrastructure/runtime_asset_cache.gd
##
## @description
## Cache centralizado em memória para recursos de textura 2D, malhas 3D e
## formas de colisão geométricas compartilhados entre múltiplos chunks no mundo.
##
## @created 2026-08-20
## @updated 2026-08-21
##
## @author Leonardo S. Badaró
extends RefCounted

static var _texture_cache: Dictionary = { }
static var _mesh_cache: Dictionary = { }
static var _convex_shape_cache: Dictionary = { }
static var _trimesh_shape_cache: Dictionary = { }
static var _trunk_shape_cache: Dictionary = { }
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


static func get_or_create_convex_shape(mesh_path: String, mesh: Mesh) -> Shape3D:
	if not mesh:
		return null

	var key = mesh_path if not mesh_path.is_empty() else str(mesh.get_instance_id())
	_mutex.lock()
	if _convex_shape_cache.has(key):
		var shape = _convex_shape_cache[key]
		_mutex.unlock()
		return shape
	_mutex.unlock()

	var new_shape = mesh.create_convex_shape()
	if new_shape:
		_mutex.lock()
		_convex_shape_cache[key] = new_shape
		_mutex.unlock()
	return new_shape


static func get_or_create_trimesh_shape(mesh_path: String, mesh: Mesh) -> Shape3D:
	if not mesh:
		return null

	var key = mesh_path if not mesh_path.is_empty() else str(mesh.get_instance_id())
	_mutex.lock()
	if _trimesh_shape_cache.has(key):
		var shape = _trimesh_shape_cache[key]
		_mutex.unlock()
		return shape
	_mutex.unlock()

	var new_shape = mesh.create_trimesh_shape()
	if new_shape:
		_mutex.lock()
		_trimesh_shape_cache[key] = new_shape
		_mutex.unlock()
	return new_shape


static func get_or_create_trunk_convex_shape(mesh_path: String, mesh: Mesh, trunk_surface_index: int = 0) -> Shape3D:
	if not mesh:
		return null

	var key = "%s_trunk_%d" % [mesh_path if not mesh_path.is_empty() else str(mesh.get_instance_id()), trunk_surface_index]
	_mutex.lock()
	if _trunk_shape_cache.has(key):
		var shape = _trunk_shape_cache[key]
		_mutex.unlock()
		return shape
	_mutex.unlock()

	var new_shape: Shape3D = null
	if mesh is ArrayMesh and mesh.get_surface_count() > trunk_surface_index:
		var arrays = mesh.surface_get_arrays(trunk_surface_index)
		if not arrays.is_empty():
			var trunk_mesh = ArrayMesh.new()
			trunk_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			new_shape = trunk_mesh.create_convex_shape()

	if not new_shape:
		new_shape = mesh.create_convex_shape()

	if new_shape:
		_mutex.lock()
		_trunk_shape_cache[key] = new_shape
		_mutex.unlock()

	return new_shape


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
	_convex_shape_cache.clear()
	_trimesh_shape_cache.clear()
	_trunk_shape_cache.clear()
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
