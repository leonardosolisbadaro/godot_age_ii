## @file test_client_orchestrator.gd
## @path res://tests/client/test_client_orchestrator.gd
##
## @description
## Testes unitarios GUT AAA do ClientOrchestrator.
## Valida a instanciacao do adaptador e inicializacao do orquestrador do cliente.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
extends GutTest

const ClientOrchestratorClass = preload("res://src/client/infrastructure/client_orchestrator.gd")


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


func test_client_orchestrator_initialization_and_adapter() -> void:
	# Arrange & Act
	var orchestrator: Node = ClientOrchestratorClass.new(false)

	# Assert
	assert_true(
		orchestrator.has_method("get_client_adapter"),
		"ClientOrchestrator deve implementar get_client_adapter.",
	)
	assert_not_null(
		orchestrator.call("get_client_adapter"),
		"ClientOrchestrator deve instanciar o QuanticNetClientAdapter.",
	)
	assert_false(orchestrator.call("is_connected_to_server"), "Cliente nao deve iniciar conectado.")
	orchestrator.free()
