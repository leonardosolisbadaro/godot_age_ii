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
const ClientOrchestratorClass = preload("res://src/client/client_orchestrator.gd")
const ServerOrchestratorClass = preload("res://src/server/server_orchestrator.gd")
const DebugWorldEditorClass = preload("res://src/debug/debug_world_editor.gd")


func test_main_client_orchestration() -> void:
	# Arrange
	var main_scene = MainScript.new()

	# Act
	main_scene._start_client(true)

	# Assert
	assert_not_null(main_scene._client_orchestrator, "ClientOrchestrator deve estar instanciado")
	assert_not_null(main_scene.get_world_chunk_manager(), "WorldChunkManager deve estar ativo")
	assert_not_null(main_scene.get_local_player(), "PlayerAvatar deve estar instanciado")

	# Cleanup
	main_scene.free()


func test_main_server_orchestration() -> void:
	# Arrange
	var main_scene = MainScript.new()

	# Act
	main_scene._start_server()

	# Assert
	assert_not_null(main_scene._server_orchestrator, "ServerOrchestrator deve estar instanciado")
	assert_not_null(main_scene.get_server_world(), "ServerWorldManager deve estar ativo")
	assert_not_null(main_scene.get_server_adapter(), "QuanticNetServerAdapter deve estar ativo")

	# Cleanup
	main_scene.free()


func test_client_orchestrator_instantiation() -> void:
	# Arrange & Act
	var client = ClientOrchestratorClass.new()
	client.is_editor_mode = true

	# Assert
	assert_not_null(client, "ClientOrchestrator deve instanciar com sucesso")

	# Cleanup
	client.free()


func test_server_orchestrator_instantiation() -> void:
	# Arrange & Act
	var server = ServerOrchestratorClass.new()

	# Assert
	assert_not_null(server, "ServerOrchestrator deve instanciar com sucesso")

	# Cleanup
	server.free()


