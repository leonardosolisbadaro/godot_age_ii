## @file test_main_orchestration.gd
## @path res://tests/unit/infrastructure/test_main_orchestration.gd
##
## @description
## Testes unitários AAA para a orquestração da cena principal (main.gd).
##
## @created 2026-08-19
## @updated 2026-08-21
##
## @author Leonardo S. Badaró
extends GutTest

const MainScript = preload("res://main.gd")


func test_main_client_orchestration() -> void:
	# Arrange
	var main_scene = MainScript.new()

	# Act
	main_scene._start_client()

	# Assert
	assert_not_null(main_scene.get_node_or_null("WorldChunkManager"), "WorldChunkManager deve estar instanciado")
	assert_not_null(main_scene.get_node_or_null("PlayerAvatar"), "PlayerAvatar deve estar instanciado")
	assert_not_null(main_scene.get_node_or_null("DebugHUD"), "DebugHUD deve estar instanciado")
	assert_not_null(main_scene.get_node_or_null("SunLight"), "SunLight deve estar instanciado")
	assert_not_null(main_scene.get_node_or_null("WorldEnvironment"), "WorldEnvironment deve estar instanciado")

	# Cleanup
	main_scene.free()


func test_main_server_orchestration() -> void:
	# Arrange
	var main_scene = MainScript.new()

	# Act
	main_scene._start_server()

	# Assert
	assert_not_null(main_scene._server_world, "ServerWorldManager deve estar ativo")
	assert_not_null(main_scene._server_adapter, "QuanticNetServerAdapter deve estar ativo")

	# Cleanup
	main_scene.free()


func test_calculate_spawn_position_fallback_and_map() -> void:
	# Arrange
	var main_scene = MainScript.new()

	# Act
	var spawn_pos = main_scene._calculate_spawn_position()

	# Assert
	assert_ne(spawn_pos, Vector3.ZERO, "Spawn position não deve ser zero")

	# Cleanup
	main_scene.free()

