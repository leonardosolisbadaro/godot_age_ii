## @file test_quantic_net_client_adapter.gd
## @path res://tests/client/test_quantic_net_client_adapter.gd
##
## @description
## Testes unitarios GUT AAA do QuanticNetClientAdapter.
## Valida ciclo de vida de conexao bare-metal (sem DTLS), propagacao de sinais
## e submissao de estados preditos.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
extends GutTest

const QuanticNetClientAdapterClass = preload(
	"res://src/client/adapters/quantic_net_client_adapter.gd"
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
	var adapter = QuanticNetClientAdapterClass.new()

	# Act & Assert
	assert_false(adapter.is_connected_to_server(), "Cliente deve iniciar desconectado.")
	assert_eq(
		adapter.get_connection_state(),
		0,
		"Estado de conexao inicial deve ser DISCONNECTED (0).",
	)


func test_signals_propagation() -> void:
	# Arrange
	var adapter = QuanticNetClientAdapterClass.new()
	watch_signals(adapter)

	# Act - State changed to CONNECTED (3)
	adapter._on_qn_state_changed(3)

	# Assert
	assert_signal_emitted(
		adapter,
		"connected_to_server",
		"Sinal connected_to_server deve ser emitido.",
	)
	assert_signal_emitted_with_parameters(adapter, "connection_state_changed", [3])

	# Act - Pong received
	adapter._on_qn_pong_received(45.5, 0.0)

	# Assert
	assert_signal_emitted_with_parameters(adapter, "pong_received", [45.5, 0.0])

	# Act - Peer Join & Left
	adapter._on_qn_peer_joined(5)
	adapter._on_qn_peer_left(5)

	# Assert
	assert_signal_emitted_with_parameters(adapter, "peer_joined", [5])
	assert_signal_emitted_with_parameters(adapter, "peer_left", [5])

	# Act - State changed to DISCONNECTED (0)
	adapter._on_qn_state_changed(0)

	# Assert
	assert_signal_emitted(
		adapter,
		"disconnected_from_server",
		"Sinal disconnected_from_server deve ser emitido.",
	)
