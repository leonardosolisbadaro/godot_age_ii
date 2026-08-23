## @file test_server_orchestrator.gd
## @path res://tests/server/test_server_orchestrator.gd
##
## @description
## Testes unitarios GUT AAA do ServerOrchestrator.
## Valida o ciclo de vida do orquestrador do servidor dedicado.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
extends GutTest

const ServerOrchestratorClass = preload("res://src/server/infrastructure/server_orchestrator.gd")


func before_each() -> void:
	if Engine.has_singleton("QuanticNet"):
		var qn = Engine.get_singleton("QuanticNet")
		if qn.has_method("disconnect_net"):
			qn.disconnect_net()


func after_each() -> void:
	if Engine.has_singleton("QuanticNet"):
		var qn = Engine.get_singleton("QuanticNet")
		if qn.has_method("disconnect_net"):
			qn.disconnect_net()


func test_server_orchestrator_initialization_and_adapter() -> void:
	# Arrange & Act
	var orchestrator: Node = ServerOrchestratorClass.new(false)

	# Assert
	assert_true(
		orchestrator.has_method("get_server_adapter"),
		"ServerOrchestrator deve implementar get_server_adapter.",
	)
	assert_not_null(
		orchestrator.call("get_server_adapter"),
		"ServerOrchestrator deve instanciar o QuanticNetServerAdapter.",
	)
	assert_false(
		orchestrator.call("is_running"),
		"Servidor nao deve estar em execucao com auto_start=false.",
	)
	orchestrator.free()


func test_server_orchestrator_start_and_stop() -> void:
	# Arrange
	var orchestrator: Node = ServerOrchestratorClass.new(false)

	# Act - Start
	var err: int = orchestrator.call("start_server", 4246, "127.0.0.1", 16, false, "test-secret")

	# Assert - Start
	assert_eq(err, OK, "start_server deve retornar OK.")
	assert_true(orchestrator.call("is_running"), "Servidor deve estar ativo.")

	# Act - Stop
	orchestrator.call("stop_server")

	# Assert - Stop
	assert_false(orchestrator.call("is_running"), "Servidor deve estar inativo apos stop.")
	orchestrator.free()
