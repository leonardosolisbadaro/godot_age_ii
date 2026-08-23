## @file test_quantic_net_server_adapter.gd
## @path res://tests/server/test_quantic_net_server_adapter.gd
##
## @description
## Testes unitarios GUT AAA do QuanticNetServerAdapter.
## Valida inicializacao bare-metal (sem DTLS), registro e saida de peers,
## e metodos de consulta de estado do servidor.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
extends GutTest

const QuanticNetServerAdapterClass = preload(
	"res://src/server/adapters/quantic_net_server_adapter.gd"
)
const NetworkConstantsClass = preload(
	"res://src/core/domain/network_constants.gd"
)


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


func test_initialization_defaults() -> void:
	# Arrange
	var adapter = QuanticNetServerAdapterClass.new()

	# Act & Assert
	assert_false(adapter.is_server_active(), "O servidor deve iniciar desativado.")
	assert_eq(adapter.get_port(), NetworkConstantsClass.DEFAULT_PORT, "Porta padrao deve ser 4242.")
	assert_eq(adapter.get_bind_ip(), NetworkConstantsClass.DEFAULT_BIND_IP, "IP padrao de bind deve ser 0.0.0.0.")
	assert_eq(adapter.get_connected_peers().size(), 0, "Lista de peers deve iniciar vazia.")


func test_start_and_stop_server() -> void:
	# Arrange
	var adapter = QuanticNetServerAdapterClass.new()
	watch_signals(adapter)

	# Act - Start
	var err = adapter.start_server(4245, "127.0.0.1", 16, "test-secret", false)

	# Assert - Start
	assert_eq(err, OK, "start_server deve retornar OK.")
	assert_true(adapter.is_server_active(), "Servidor deve estar marcado como ativo.")
	assert_eq(adapter.get_port(), 4245, "Porta deve ser atualizada para 4245.")
	assert_signal_emitted(adapter, "server_started", "Sinal server_started deve ser emitido.")

	# Act - Stop
	adapter.stop_server()

	# Assert - Stop
	assert_false(adapter.is_server_active(), "Servidor deve estar desativado apos stop.")
	assert_signal_emitted(adapter, "server_stopped", "Sinal server_stopped deve ser emitido.")


func test_peer_joined_and_left_lifecycle() -> void:
	# Arrange
	var adapter = QuanticNetServerAdapterClass.new()
	watch_signals(adapter)

	# Act - Peer Join
	adapter._on_qn_peer_joined(10)
	adapter._on_qn_peer_joined(20)

	# Assert - Peer Join
	assert_eq(adapter.get_connected_peers().size(), 2, "Devem haver 2 peers registrados.")
	assert_true(adapter.get_connected_peers().has(10), "Peer 10 deve estar na lista.")
	assert_true(adapter.get_connected_peers().has(20), "Peer 20 deve estar na lista.")
	assert_signal_emit_count(
		adapter,
		"peer_joined",
		2,
		"Sinal peer_joined deve ser emitido duas vezes.",
	)

	# Act - Peer Left
	adapter._on_qn_peer_left(10)

	# Assert - Peer Left
	assert_eq(adapter.get_connected_peers().size(), 1, "Deve restar 1 peer apos saida.")
	assert_false(adapter.get_connected_peers().has(10), "Peer 10 nao deve mais estar na lista.")
	assert_true(adapter.get_connected_peers().has(20), "Peer 20 deve permanecer na lista.")
	assert_signal_emit_count(adapter, "peer_left", 1, "Sinal peer_left deve ser emitido uma vez.")
