## @file test_debug_ide_host.gd
## @path res://tests/debug/test_debug_ide_host.gd
##
## @description
## Testes unitarios GUT AAA do DebugIdeHost.
## Valida instanciacao de janelas individuais (DebugWindow) para Telemetria de Rede,
## Telemetria de Graficos e Logs de Rede, alem de controle de visibilidade.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
extends GutTest

const DebugIdeHostClass = preload("res://src/debug/debug_ide_host.gd")
const QuanticNetClientAdapterClass = preload(
	"res://src/client/adapters/quantic_net_client_adapter.gd"
)


func test_initialization_and_panels_presence() -> void:
	# Arrange & Act
	var host = DebugIdeHostClass.new()
	add_child_autofree(host)

	# Assert
	assert_not_null(host.get_telemetry_window(), "NetTelemetryWindow deve existir no host.")
	assert_not_null(host.get_graphics_window(), "GraphicsTelemetryWindow deve existir no host.")
	assert_not_null(host.get_logs_window(), "LogsWindow deve existir no host.")
	assert_not_null(host.get_file_menu(), "Menu Arquivo deve existir.")
	assert_not_null(host.get_tools_menu(), "Menu Ferramentas deve existir.")
	assert_true(host.is_ide_visible(), "Mini-IDE deve iniciar visivel por padrao.")
	assert_false(host.get_telemetry_window().is_open(), "Telemetria de rede deve iniciar fechada.")
	assert_false(
		host.get_graphics_window().is_open(),
		"Telemetria de graficos deve iniciar fechada.",
	)
	assert_false(host.get_logs_window().is_open(), "Logs de rede deve iniciar fechado.")


func test_toggle_visibility() -> void:
	# Arrange
	var host = DebugIdeHostClass.new()
	add_child_autofree(host)

	# Act - 1st toggle
	host.toggle_visibility()

	# Assert - 1st toggle
	assert_false(host.is_ide_visible(), "Mini-IDE deve estar oculta apos 1o toggle.")

	# Act - 2nd toggle
	host.toggle_visibility()

	# Assert - 2nd toggle
	assert_true(host.is_ide_visible(), "Mini-IDE deve estar visivel apos 2o toggle.")


func test_setup_with_client_adapter() -> void:
	# Arrange
	var host = DebugIdeHostClass.new()
	var adapter = QuanticNetClientAdapterClass.new()
	add_child_autofree(host)

	# Act
	host.setup(adapter)

	# Assert
	assert_not_null(host.get_telemetry_panel(), "TelemetryPanel deve continuar valido.")
	assert_gt(
		host.get_connection_logs_panel().get_log_entries_count(),
		0,
		"LogsPanel deve registrar setup.",
	)


func test_tools_menu_opens_individual_windows() -> void:
	# Arrange
	var host = DebugIdeHostClass.new()
	add_child_autofree(host)

	# Assert inicial
	assert_false(host.get_telemetry_window().is_open(), "Telemetria de rede deve iniciar fechada.")
	assert_false(
		host.get_graphics_window().is_open(),
		"Telemetria de graficos deve iniciar fechada.",
	)
	assert_false(host.get_logs_window().is_open(), "Logs deve iniciar fechado.")

	# Act - Abrir Telemetria de Rede
	host._on_tools_menu_item_pressed(DebugIdeHostClass.MENU_TOOLS_ID_NET_TELEMETRY)
	assert_true(host.get_telemetry_window().is_open(), "Telemetria de rede deve estar aberta.")

	# Act - Abrir Telemetria de Gráficos
	host._on_tools_menu_item_pressed(DebugIdeHostClass.MENU_TOOLS_ID_GRAPHICS_TELEMETRY)
	assert_true(host.get_graphics_window().is_open(), "Telemetria de graficos deve estar aberta.")

	# Act - Abrir Logs de Rede
	host._on_tools_menu_item_pressed(DebugIdeHostClass.MENU_TOOLS_ID_LOGS)
	assert_true(host.get_logs_window().is_open(), "Logs deve estar aberto.")

	# Act - Fechar uma janela individual
	host.get_telemetry_window().close_window()
	assert_false(
		host.get_telemetry_window().is_open(),
		"Telemetria de rede deve fechar pelo botao X.",
	)
	assert_true(host.get_graphics_window().is_open(), "Telemetria de graficos permanece aberta.")
	assert_true(host.get_logs_window().is_open(), "Logs permanece aberto.")
