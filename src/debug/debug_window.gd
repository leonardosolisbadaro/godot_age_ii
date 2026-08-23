## @file debug_window.gd
## @path res://src/debug/debug_window.gd
##
## @description
## Classe base abstrata e reutilizavel para todas as janelas de diagnostico da Mini-IDE.
## Centraliza a estilizacao visual (dark theme, bordas), barra de titulo arrastavel
## (Drag & Drop), botao 'X' de fechamento, foco (move_to_front) e o container de conteudo
## vertical (_content_vbox) populado pelas subclasses via _build_content().
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
class_name DebugWindow
extends PanelContainer

# ==============================================================================
# SINAIS
# ==============================================================================

signal window_opened()
signal window_closed()

# ==============================================================================
# CONSTANTES DE ESTILO (DEVTOOL DARK)
# ==============================================================================

const COLOR_BG: Color = Color(0.10, 0.10, 0.13, 0.96)
const COLOR_BORDER: Color = Color(0.24, 0.26, 0.30, 1.0)
const COLOR_TOP_BAR: Color = Color(0.14, 0.14, 0.18, 1.0)
const COLOR_TITLE_TEXT: Color = Color(0.85, 0.88, 0.92)

# ==============================================================================
# ELEMENTOS VISUAIS PROTEGIDOS
# ==============================================================================

var _title_label: Label
var _close_button: Button
var _top_bar: PanelContainer
var _content_margin: MarginContainer
var _content_vbox: VBoxContainer

# ==============================================================================
# ESTADO DE ARRASTO E JANELA
# ==============================================================================

var window_title: String = "Janela de Debug"
var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO


func _init(title: String = "Janela de Debug", initial_width: float = 340.0) -> void:
	window_title = title
	custom_minimum_size = Vector2(initial_width, 0.0)
	visible = false
	_build_base_ui()


func _ready() -> void:
	_build_base_ui()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		move_to_front()

# ==============================================================================
# CONSTRUÇÃO DA ESTRUTURA BASE DA JANELA
# ==============================================================================


func _build_base_ui() -> void:
	if _content_vbox != null:
		return

	var win_style = StyleBoxFlat.new()
	win_style.bg_color = COLOR_BG
	win_style.border_color = COLOR_BORDER
	win_style.set_border_width_all(1)
	win_style.set_corner_radius_all(4)
	win_style.content_margin_left = 6.0
	win_style.content_margin_right = 6.0
	win_style.content_margin_top = 4.0
	win_style.content_margin_bottom = 6.0
	add_theme_stylebox_override("panel", win_style)

	var main_vbox = VBoxContainer.new()
	main_vbox.name = "WindowMainVBox"
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 4)
	add_child(main_vbox)

	# Barra de Título Arrastável
	_top_bar = PanelContainer.new()
	_top_bar.name = "TopBar"
	_top_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	_top_bar.gui_input.connect(_on_top_bar_gui_input)

	var top_bar_style = StyleBoxFlat.new()
	top_bar_style.bg_color = COLOR_TOP_BAR
	top_bar_style.border_color = COLOR_BORDER
	top_bar_style.border_width_bottom = 1
	top_bar_style.content_margin_left = 6.0
	top_bar_style.content_margin_right = 4.0
	top_bar_style.content_margin_top = 2.0
	top_bar_style.content_margin_bottom = 2.0
	_top_bar.add_theme_stylebox_override("panel", top_bar_style)
	main_vbox.add_child(_top_bar)

	var top_hbox = HBoxContainer.new()
	top_hbox.name = "TopHBox"
	top_hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_top_bar.add_child(top_hbox)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = " " + window_title
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_title_label.add_theme_color_override("font_color", COLOR_TITLE_TEXT)
	top_hbox.add_child(_title_label)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = " X "
	_close_button.flat = true
	_close_button.pressed.connect(close_window)
	top_hbox.add_child(_close_button)

	# Container de Conteúdo com Margens
	_content_margin = MarginContainer.new()
	_content_margin.name = "ContentMargin"
	_content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_margin.add_theme_constant_override("margin_left", 4)
	_content_margin.add_theme_constant_override("margin_right", 4)
	_content_margin.add_theme_constant_override("margin_top", 4)
	_content_margin.add_theme_constant_override("margin_bottom", 4)
	main_vbox.add_child(_content_margin)

	_content_vbox = VBoxContainer.new()
	_content_vbox.name = "ContentVBox"
	_content_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_theme_constant_override("separation", 4)
	_content_margin.add_child(_content_vbox)

	_build_content()

# ==============================================================================
# HOOK VIRTUAL PARA SUBCLASSES
# ==============================================================================


## Método virtual a ser implementado pelas subclasses para adicionar seus nós.
func _build_content() -> void:
	pass

# ==============================================================================
# MÉTODOS DE ACESSO E CONTROLE DE CICLO DE VIDA
# ==============================================================================


## Retorna o container vertical onde o conteúdo específico do painel deve ser inserido.
func get_content_vbox() -> VBoxContainer:
	return _content_vbox


## Abre a janela e coloca-a em primeiro plano.
func open_window() -> void:
	visible = true
	move_to_front()
	window_opened.emit()


## Fecha a janela.
func close_window() -> void:
	visible = false
	_is_dragging = false
	window_closed.emit()


## Alterna entre aberta e fechada.
func toggle_window() -> void:
	if visible:
		close_window()
	else:
		open_window()


func is_open() -> bool:
	return visible


func set_window_title(new_title: String) -> void:
	window_title = new_title
	if _title_label != null:
		_title_label.text = " " + new_title

# ==============================================================================
# LÓGICA DE ARRASTO (DRAG & DROP)
# ==============================================================================


func _on_top_bar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_dragging = true
				_drag_offset = get_global_mouse_position() - global_position
				move_to_front()
			else:
				_is_dragging = false

	elif event is InputEventMouseMotion and _is_dragging:
		var new_pos = get_global_mouse_position() - _drag_offset
		new_pos.y = maxf(new_pos.y, 28.0)
		global_position = new_pos


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = false
