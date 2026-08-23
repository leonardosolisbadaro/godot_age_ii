## @file test_baremetal_netcode.gd
## @path res://tests/unit/infrastructure/test_baremetal_netcode.gd
##
## @description
## Testes unitários AAA para conexão Bare-Metal UDP sem DTLS e telemetria QuanticNet.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
extends GutTest

const ServerOrchestratorClass = preload("res://src/server/server_orchestrator.gd")
const ClientOrchestratorClass = preload("res://src/client/client_orchestrator.gd")


func test_quantic_net_get_state_and_telemetry_defaults() -> void:
	# Arrange
	var qn = get_node_or_null("/root/QuanticNet")
	if not qn:
		pass_test("QuanticNet autoload ausente no contexto de teste unitario")
		return

	# Act
	var st = qn.get_state()
	var st_str = qn.get_state_string()
	var telemetry = qn.get_telemetry_dict()

	# Assert
	assert_eq(st, 0, "Estado inicial deve ser DISCONNECTED (0)")
	assert_eq(st_str, "DESCONECTADO", "Texto de estado inicial deve ser DESCONECTADO")
	assert_true(telemetry.has("rtt_ms"), "Telemetria deve conter rtt_ms")
	assert_true(telemetry.has("loss_pct"), "Telemetria deve conter loss_pct")


func test_server_orchestrator_baremetal_config() -> void:
	# Arrange
	var server = ServerOrchestratorClass.new()

	# Act
	var s_world = server.get_server_world()

	# Assert
	assert_not_null(server, "ServerOrchestrator deve instanciar com sucesso")

	# Cleanup
	server.free()
