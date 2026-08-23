## @file test_server_navmesh.gd
## @path res://tests/unit/infrastructure/test_server_navmesh.gd
##
## @description
## Testes unitários AAA para carregamento e consultas da NavMesh do Servidor.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
extends GutTest

const ChunkResourceAdapterClass = preload("res://src/adapters/chunk_resource_adapter.gd")
const ServerWorldManagerClass = preload("res://src/infrastructure/server_world_manager.gd")


func test_chunk_resource_adapter_loads_compiled_navmesh() -> void:
	# Arrange
	var adapter = ChunkResourceAdapterClass.new("res://assets/maps")

	# Act
	var navmesh = adapter.load_chunk_navmesh("17_25")

	# Assert
	assert_not_null(navmesh, "NavMesh de 17_25 compilada deve ser carregada")
	assert_gt(navmesh.get_polygon_count(), 0, "NavMesh deve conter mais de 0 poligonos")
	assert_gt(navmesh.get_vertices().size(), 0, "NavMesh deve conter mais de 0 vertices")


func test_server_world_manager_navmesh_integration() -> void:
	# Arrange
	var server_manager = ServerWorldManagerClass.new("res://assets/maps")

	# Act
	var loaded = server_manager.load_server_chunk("17_25")
	var navmesh = server_manager.get_chunk_navmesh("17_25")

	# Assert
	assert_true(loaded, "Chunk 17_25 deve ser carregado no ServerWorldManager")
	assert_not_null(navmesh, "NavMesh de 17_25 deve estar registrada")
	assert_true(server_manager.get_nav_map_rid().is_valid(), "RID do mapa de navegacao deve ser valido")

	# Act & Assert 2: Teste de ponto navegável na vila de Talking Island (-4395.84, -187.12, 21983.23)
	var test_pos = Vector3(-4395.84, -187.12, 21983.23)
	var closest = server_manager.get_closest_navigable_point(test_pos)
	assert_gt(closest.length(), 0.0, "Ponto navegavel mais proximo deve ser valido")

	# Cleanup
	server_manager.cleanup()
