## @file debug_ide_host.gd
## @path res://src/debug/debug_ide_host.gd
##
## @description
## Hospedeiro visual em overlay (CanvasLayer) da Mini-IDE de desenvolvimento.
## Fornece uma barra de menu fixa no topo da janela (Arquivo, Ferramentas)
## e orquestra as janelas flutuantes e arrastaveis (DebugWindow) de telemetria e logs.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
class_name DebugIdeHost
extends CanvasLayer

# ==============================================================================
# DEPENDÊNCIAS PRELOAD
# ==============================================================================

const QuanticNetClientAdapterClass = preload(
	"res://src/client/adapters/quantic_net_client_adapter.gd"
)
const DebugWindowClass = preload("res://src/debug/debug_window.gd")
const TelemetryPanelClass = preload("res://src/debug/panels/telemetry_panel.gd")
const GraphicsTelemetryPanelClass = preload("res://src/debug/panels/graphics_telemetry_panel.gd")
const ConnectionLogsPanelClass = preload("res://src/debug/panels/connection_logs_panel.gd")

# ==============================================================================
# CONSTANTES DE MENU
# ==============================================================================

const MENU_FILE_ID_CLOSE: int = 0
const MENU_TOOLS_ID_NET_TELEMETRY: int = 0
const MENU_TOOLS_ID_GRAPHICS_TELEMETRY: int = 1
const MENU_TOOLS_ID_LOGS: int = 2

# ==============================================================================
# ELEMENTOS VISUAIS
# ==============================================================================

var _root_control: Control
var _top_menu_bar: PanelContainer
var _telemetry_panel: TelemetryPanelClass
var _graphics_panel: GraphicsTelemetryPanelClass
var _connection_logs_panel: ConnectionLogsPanelClass
var _file_menu: MenuButton
var _tools_menu: MenuButton
var _is_visible: bool = true


func _init() -> void:
	name = "DebugIdeHost"
	layer = 100


func _ready() -> void:
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2:
			toggle_visibility()

# ==============================================================================
# INICIALIZAÇÃO E INJEÇÃO DE DEPENDÊNCIAS
# ==============================================================================


## Conecta todos os subpaineis da Mini-IDE ao adaptador do cliente.
func setup(client_adapter: QuanticNetClientAdapterClass) -> void:
	if _telemetry_panel != null:
		_telemetry_panel.setup(client_adapter)
	if _connection_logs_panel != null:
		_connection_logs_panel.setup(client_adapter)


## Alterna a exibição de toda a interface da Mini-IDE (Menu Bar + Janelas).
func toggle_visibility() -> void:
	_is_visible = not _is_visible
	if _root_control != null:
		_root_control.visible = _is_visible


func set_ide_visible(visible_state: bool) -> void:
	_is_visible = visible_state
	if _root_control != null:
		_root_control.visible = _is_visible


func is_ide_visible() -> bool:
	return _is_visible

# ==============================================================================
# CONSTRUÇÃO DA INTERFACE VISUAL
# ==============================================================================


func _build_ui() -> void:
	_root_control = Control.new()
	_root_control.name = "RootControl"
	_root_control.anchor_right = 1.0
	_root_control.anchor_bottom = 1.0
	_root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root_control)

	_build_top_menu_bar()
	_build_windows()


func _build_top_menu_bar() -> void:
	_top_menu_bar = PanelContainer.new()
	_top_menu_bar.name = "TopMenuBar"
	_top_menu_bar.anchor_right = 1.0
	_top_menu_bar.offset_left = 0.0
	_top_menu_bar.offset_top = 0.0
	_top_menu_bar.offset_right = 0.0
	_top_menu_bar.offset_bottom = 28.0
	_top_menu_bar.custom_minimum_size = Vector2(0, 28)

	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color(0.11, 0.11, 0.13, 0.98)
	bar_style.border_color = Color(0.20, 0.20, 0.24, 1.0)
	bar_style.border_width_bottom = 1
	bar_style.content_margin_left = 6.0
	bar_style.content_margin_right = 10.0
	bar_style.content_margin_top = 2.0
	bar_style.content_margin_bottom = 2.0
	_top_menu_bar.add_theme_stylebox_override("panel", bar_style)
	_root_control.add_child(_top_menu_bar)

	var menu_hbox = HBoxContainer.new()
	menu_hbox.name = "MenuHBox"
	menu_hbox.add_theme_constant_override("separation", 2)
	_top_menu_bar.add_child(menu_hbox)

	# Menu Arquivo
	_file_menu = MenuButton.new()
	_file_menu.name = "FileMenu"
	_file_menu.text = "Arquivo"
	_file_menu.flat = true
	var file_popup = _file_menu.get_popup()
	file_popup.add_item("Toggle IDE (F2)", MENU_FILE_ID_CLOSE)
	file_popup.id_pressed.connect(_on_file_menu_item_pressed)
	menu_hbox.add_child(_file_menu)

	# Menu Ferramentas
	_tools_menu = MenuButton.new()
	_tools_menu.name = "ToolsMenu"
	_tools_menu.text = "Ferramentas"
	_tools_menu.flat = true
	var tools_popup = _tools_menu.get_popup()
	tools_popup.add_item("Telemetria de Rede", MENU_TOOLS_ID_NET_TELEMETRY)
	tools_popup.add_item("Telemetria de Gráficos", MENU_TOOLS_ID_GRAPHICS_TELEMETRY)
	tools_popup.add_item("Logs de Rede", MENU_TOOLS_ID_LOGS)
	tools_popup.id_pressed.connect(_on_tools_menu_item_pressed)
	menu_hbox.add_child(_tools_menu)

	var dev_lbl = Label.new()
	dev_lbl.text = "DevTool / godot_age_ii"
	dev_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dev_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dev_lbl.add_theme_color_override("font_color", Color(0.5, 0.52, 0.58))
	menu_hbox.add_child(dev_lbl)


func _build_windows() -> void:
	# Janela 1: Telemetria de Rede (DebugWindow auto-contida)
	_telemetry_panel = TelemetryPanelClass.new()
	_telemetry_panel.name = "NetTelemetryWindow"
	_telemetry_panel.position = Vector2(16, 40)
	_telemetry_panel.close_window()
	_root_control.add_child(_telemetry_panel)

	# Janela 2: Telemetria de Gráficos (DebugWindow auto-contida)
	_graphics_panel = GraphicsTelemetryPanelClass.new()
	_graphics_panel.name = "GraphicsTelemetryWindow"
	_graphics_panel.position = Vector2(370, 40)
	_graphics_panel.close_window()
	_root_control.add_child(_graphics_panel)

	# Janela 3: Logs de Rede (DebugWindow auto-contida)
	_connection_logs_panel = ConnectionLogsPanelClass.new()
	_connection_logs_panel.name = "LogsWindow"
	_connection_logs_panel.position = Vector2(16, 280)
	_connection_logs_panel.close_window()
	_root_control.add_child(_connection_logs_panel)

# ==============================================================================
# MANIPULADORES DE MENU
# ==============================================================================


func _on_file_menu_item_pressed(id: int) -> void:
	match id:
		MENU_FILE_ID_CLOSE:
			toggle_visibility()


func _on_tools_menu_item_pressed(id: int) -> void:
	match id:
		MENU_TOOLS_ID_NET_TELEMETRY:
			if _telemetry_panel != null:
				_telemetry_panel.open_window()
		MENU_TOOLS_ID_GRAPHICS_TELEMETRY:
			if _graphics_panel != null:
				_graphics_panel.open_window()
		MENU_TOOLS_ID_LOGS:
			if _connection_logs_panel != null:
				_connection_logs_panel.open_window()

# ==============================================================================
# MÉTODOS DE ACESSO PARA TESTES
# ==============================================================================


func get_telemetry_panel() -> TelemetryPanelClass:
	return _telemetry_panel


func get_graphics_panel() -> GraphicsTelemetryPanelClass:
	return _graphics_panel


func get_connection_logs_panel() -> ConnectionLogsPanelClass:
	return _connection_logs_panel


func get_telemetry_window() -> DebugWindowClass:
	return _telemetry_panel


func get_graphics_window() -> DebugWindowClass:
	return _graphics_panel


func get_logs_window() -> DebugWindowClass:
	return _connection_logs_panel


func get_file_menu() -> MenuButton:
	return _file_menu


func get_tools_menu() -> MenuButton:
	return _tools_menu
