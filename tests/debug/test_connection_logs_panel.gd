## @file test_connection_logs_panel.gd
## @path res://tests/debug/test_connection_logs_panel.gd
##
## @description
## Testes unitarios GUT AAA do ConnectionLogsPanel.
## Valida registro de eventos, limpeza de logs e observacao de sinais do adaptador.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
extends GutTest

const ConnectionLogsPanelClass = preload("res://src/debug/panels/connection_logs_panel.gd")
const QuanticNetClientAdapterClass = preload(
	"res://src/client/adapters/quantic_net_client_adapter.gd"
)


func test_initialization_defaults() -> void:
	# Arrange & Act
	var panel = ConnectionLogsPanelClass.new()
	add_child_autofree(panel)

	# Assert
	assert_eq(panel.get_log_entries_count(), 0, "Historico de logs deve iniciar vazio.")


func test_event_logging_and_clear() -> void:
	# Arrange
	var panel = ConnectionLogsPanelClass.new()
	add_child_autofree(panel)

	# Act - Log Eventos
	panel.log_event("Teste 1")
	panel.log_event("Teste 2")

	# Assert - Log Eventos
	assert_eq(panel.get_log_entries_count(), 2, "Devem haver 2 entradas de log.")

	# Act - Clear
	panel.clear_logs()

	# Assert - Clear
	assert_eq(panel.get_log_entries_count(), 0, "Logs devem estar vazios apos clear.")


func test_adapter_signal_logging() -> void:
	# Arrange
	var adapter = QuanticNetClientAdapterClass.new()
	var panel = ConnectionLogsPanelClass.new()
	add_child_autofree(panel)
	panel.setup(adapter)

	# Act
	panel._on_connected()
	panel._on_peer_joined(5)
	panel._on_peer_left(5)
	panel._on_disconnected()

	# Assert (setup log + 4 eventos = 5 entradas)
	assert_eq(panel.get_log_entries_count(), 5, "Devem haver 5 entradas de log registradas.")
