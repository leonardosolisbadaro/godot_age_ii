## @file test_telemetry_panel.gd
## @path res://tests/debug/test_telemetry_panel.gd
##
## @description
## Testes unitarios GUT AAA do TelemetryPanel.
## Valida recepcao de sinais de pong (RTT, Offset), calculo de Jitter,
## contadores de amostras e ciclo de vida visual.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
extends GutTest

const TelemetryPanelClass = preload("res://src/debug/panels/telemetry_panel.gd")
const QuanticNetClientAdapterClass = preload(
	"res://src/client/adapters/quantic_net_client_adapter.gd"
)


func test_initialization_defaults() -> void:
	# Arrange & Act
	var panel = TelemetryPanelClass.new()
	add_child_autofree(panel)

	# Assert
	assert_eq(panel.get_current_rtt(), 0.0, "RTT inicial deve ser 0.")
	assert_eq(panel.get_jitter(), 0.0, "Jitter inicial deve ser 0.")
	assert_eq(panel.get_pong_count(), 0, "Contagem de pongs deve ser 0.")


func test_pong_telemetry_and_jitter_calculation() -> void:
	# Arrange
	var adapter = QuanticNetClientAdapterClass.new()
	var panel = TelemetryPanelClass.new()
	add_child_autofree(panel)
	panel.setup(adapter)

	# Act - 1st Pong
	panel._on_pong_received(50.0, 5.0)

	# Assert - 1st Pong
	assert_eq(panel.get_current_rtt(), 50.0, "RTT deve ser 50ms.")
	assert_eq(panel.get_jitter(), 0.0, "Jitter na 1a amostra deve ser 0.")
	assert_eq(panel.get_pong_count(), 1, "Deve ter 1 amostra de pong.")

	# Act - 2nd Pong (variação de 20ms)
	panel._on_pong_received(70.0, 4.5)

	# Assert - 2nd Pong
	assert_eq(panel.get_current_rtt(), 70.0, "RTT atual deve ser 70ms.")
	assert_eq(panel.get_jitter(), 20.0, "Jitter deve ser |70 - 50| = 20ms.")
	assert_eq(panel.get_pong_count(), 2, "Deve ter 2 amostras de pong.")


func test_disconnected_resets_metrics() -> void:
	# Arrange
	var adapter = QuanticNetClientAdapterClass.new()
	var panel = TelemetryPanelClass.new()
	add_child_autofree(panel)
	panel.setup(adapter)
	panel._on_pong_received(60.0, 2.0)

	# Act
	panel._on_disconnected()

	# Assert
	assert_eq(panel.get_current_rtt(), 0.0, "RTT deve ser zerado apos desconectar.")
	assert_eq(panel.get_jitter(), 0.0, "Jitter deve ser zerado apos desconectar.")
	assert_eq(panel.get_pong_count(), 0, "Contagem de pongs deve ser zerada.")
