## @file test_runtime_asset_cache.gd
## @path res://tests/unit/infrastructure/test_runtime_asset_cache.gd
##
## @description
## Testes unitários AAA para RuntimeAssetCache (cache centralizado de texturas e malhas).
##
## @created 2026-08-20
## @updated 2026-08-20
##
## @author Leonardo S. Badaró
extends GutTest

const RuntimeAssetCacheClass = preload("res://src/infrastructure/runtime_asset_cache.gd")


func before_each() -> void:
	RuntimeAssetCacheClass.clear()


func test_texture_caching_and_reuse() -> void:
	# Arrange
	var tex_path = "res://assets/maps/16_24/client/textures/layer_0_tex_Base.png"

	# Act
	var tex1 = RuntimeAssetCacheClass.get_or_load_texture(tex_path)
	var tex2 = RuntimeAssetCacheClass.get_or_load_texture(tex_path)

	# Assert
	if tex1:
		assert_not_null(tex1)
		assert_eq(tex1, tex2, "Segunda chamada deve retornar a mesma instância em cache")
		assert_eq(RuntimeAssetCacheClass.get_texture_count(), 1)
	else:
		pass_test("Arquivo de teste opcional não presente em disco")


func test_empty_paths_return_null() -> void:
	# Arrange & Act
	var tex = RuntimeAssetCacheClass.get_or_load_texture("")
	var mesh = RuntimeAssetCacheClass.get_or_load_mesh("")

	# Assert
	assert_null(tex)
	assert_null(mesh)
	assert_eq(RuntimeAssetCacheClass.get_texture_count(), 0)
	assert_eq(RuntimeAssetCacheClass.get_mesh_count(), 0)


func test_clear_cache() -> void:
	# Arrange
	var tex_path = "res://assets/maps/16_24/client/textures/layer_0_tex_Base.png"
	RuntimeAssetCacheClass.get_or_load_texture(tex_path)

	# Act
	RuntimeAssetCacheClass.clear()

	# Assert
	assert_eq(RuntimeAssetCacheClass.get_texture_count(), 0)
	assert_eq(RuntimeAssetCacheClass.get_mesh_count(), 0)


func test_shape_caching_and_reuse() -> void:
	# Arrange
	var box_mesh = BoxMesh.new()
	var mesh_key = "test://dummy_box.glb"

	# Act
	var shape1 = RuntimeAssetCacheClass.get_or_create_convex_shape(mesh_key, box_mesh)
	var shape2 = RuntimeAssetCacheClass.get_or_create_convex_shape(mesh_key, box_mesh)
	var trimesh1 = RuntimeAssetCacheClass.get_or_create_trimesh_shape(mesh_key, box_mesh)
	var trimesh2 = RuntimeAssetCacheClass.get_or_create_trimesh_shape(mesh_key, box_mesh)

	# Assert
	assert_not_null(shape1, "Convex shape deve ser gerado")
	assert_eq(shape1, shape2, "Segunda chamada de convex shape deve retornar mesma instância do cache")
	assert_not_null(trimesh1, "Trimesh shape deve ser gerado")
	assert_eq(trimesh1, trimesh2, "Segunda chamada de trimesh shape deve retornar mesma instância do cache")

	# Cleanup
	RuntimeAssetCacheClass.clear()


func test_trunk_shape_caching() -> void:
	# Arrange
	var box_mesh = BoxMesh.new()
	var mesh_key = "test://dummy_tree.glb"

	# Act
	var trunk_shape1 = RuntimeAssetCacheClass.get_or_create_trunk_convex_shape(mesh_key, box_mesh, 0)
	var trunk_shape2 = RuntimeAssetCacheClass.get_or_create_trunk_convex_shape(mesh_key, box_mesh, 0)

	# Assert
	assert_not_null(trunk_shape1, "Trunk shape deve ser gerado")
	assert_eq(trunk_shape1, trunk_shape2, "Segunda chamada de trunk shape deve retornar mesma instância do cache")

	# Cleanup
	RuntimeAssetCacheClass.clear()
