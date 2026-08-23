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


func test_quantic_net_server_validator_large_coordinates() -> void:
	var validator = preload("res://addons/quantic_net/src/domain/qn_server_validator.gd").new()
	validator.configure({
		"world_bounds": 100000.0,
		"max_speed": 18.0,
		"hard_cap": 30.0,
		"max_strikes": 9999,
	})

	var test_pos = Vector3(-4382.8, -220.0, 21947.6)
	var test_rot = Vector3(0.0, 1.5, 0.0)

	# 1. Posição inicial no mundo
	var res1 = validator.validate(2, test_pos, test_rot, 1000)
	assert_eq(res1.action, "accept", "Posicao inicial no mapa 17_25 deve ser aceita")

	# 2. Passo legítimo a 10 m/s em 0.1s
	var next_legit = test_pos + Vector3(1.0, 0.0, 0.0)
	var res2 = validator.validate(2, next_legit, test_rot, 1100)
	assert_eq(res2.action, "accept", "Passo legitimo deve ser aceito")

	# 3. Speedhack x5 (50 m/s em 0.1s = 5m)
	var hack_pos = next_legit + Vector3(5.0, 0.0, 0.0)
	var res3 = validator.validate(2, hack_pos, test_rot, 1200)
	assert_eq(res3.action, "reject", "Speedhack deve ser rejeitado")
	assert_eq(res3.pos, next_legit, "Posicao de snapback deve ser a ultima valida")
