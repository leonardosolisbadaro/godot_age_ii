## @file debug_hud.gd
## @path res://src/infrastructure/debug_hud.gd
##
## @description
## Mini-IDE de Desenvolvimento In-Game para inspeção de terreno, atores, atmosfera,
## colisões e navegação espacial no Godotage II. Apresenta barra superior de ferramentas,
## janelas flutuantes arrastáveis com visual sólido e sistema de navegação em cascata via ESC.
##
## @created 2026-08-19
## @updated 2026-08-22
##
## @author Leonardo S. Badaró
extends CanvasLayer

const RuntimeAssetCacheClass = preload("res://src/infrastructure/runtime_asset_cache.gd")

# ==============================================================================
# SINAIS DE EVENTOS DA MINI-IDE
# ==============================================================================

signal actor_selected(actor_dict: Dictionary)
signal actor_transform_applied(
	actor_name: String,
	pos: Vector3,
	rot_deg: Vector3,
	scale: Vector3,
	chunk_name: String,
)
signal actor_fix_saved(
	actor_name: String,
	pos: Vector3,
	rot_deg: Vector3,
	scale: Vector3,
	chunk_name: String,
)
signal actor_reset_requested(actor_name: String, chunk_name: String)
signal actor_collision_changed(
	actor_name: String,
	new_type: String,
	chunk_name: String,
	package_name: String,
	mesh_name: String,
)
signal actor_collision_save_requested(
	package_name: String,
	mesh_name: String,
	collision_type: String,
)
signal batch_save_requested()
signal batch_discard_requested()
signal teleport_requested(target_pos: Vector3)
signal bookmark_save_requested(name: String, pos: Vector3, chunk_name: String)
signal radius_changed(new_radius: float)

signal toggle_wireframe_requested()
signal toggle_collisions_requested()
signal toggle_shadows_requested()

signal water_volume_transform_applied(chunk_name: String, volume_name: String, data: Dictionary)
signal water_volume_fix_saved(chunk_name: String, volume_name: String, data: Dictionary)
signal water_volume_reset_requested(chunk_name: String, volume_name: String)
signal water_volumes_refresh_requested(chunk_name: String)

signal speedhack_toggled(active: bool)
signal force_teleport_requested(forward_distance: float)
signal noclip_toggled(active: bool)
signal flyhack_requested(altitude_offset: float)

# ==============================================================================
# CONSTANTES DE DESIGN E TEMA SÓLIDO
# ==============================================================================

const TOP_BAR_HEIGHT: float = 32.0
const BYTES_TO_MB: float = 1048576.0

const COLOR_BG_TOPBAR: Color = Color(0.08, 0.09, 0.12, 1.0)
const COLOR_BG_WINDOW: Color = Color(0.11, 0.12, 0.16, 0.98)
const COLOR_BG_HEADER: Color = Color(0.15, 0.17, 0.22, 1.0)
const COLOR_BG_INPUT: Color = Color(0.07, 0.08, 0.10, 1.0)
const COLOR_BG_BUTTON: Color = Color(0.16, 0.18, 0.24, 1.0)
const COLOR_BG_BUTTON_HOVER: Color = Color(0.22, 0.25, 0.33, 1.0)
const COLOR_BG_BUTTON_PRESSED: Color = Color(0.12, 0.14, 0.18, 1.0)
const COLOR_BORDER: Color = Color(0.24, 0.28, 0.36, 1.0)
const COLOR_BORDER_FOCUSED: Color = Color(0.35, 0.55, 0.85, 1.0)
const COLOR_TEXT_MUTED: Color = Color(0.65, 0.70, 0.80, 1.0)
const COLOR_TEXT_ACCENT: Color = Color(0.35, 0.75, 1.0, 1.0)
const COLOR_TEXT_WARN: Color = Color(1.0, 0.85, 0.25, 1.0)
const COLOR_TEXT_SUCCESS: Color = Color(0.30, 0.90, 0.50, 1.0)

# ==============================================================================
# COMPONENTES DA TOP BAR
# ==============================================================================

var _top_bar: Panel
var _menu_file: MenuButton
var _menu_view: MenuButton
var _menu_tools: MenuButton
var _label_quick_badge: Label

# ==============================================================================
# JANELAS FLUTUANTES ARRASTÁVEIS
# ==============================================================================

var _telemetry_window: PanelContainer
var _label_telemetry_body: Label

var _outliner_window: PanelContainer
var _search_input: LineEdit
var _item_list: ItemList
var _slider_radius: HSlider
var _label_radius_val: Label
var _label_outliner_footer: Label
var _btn_batch_save: Button
var _btn_batch_discard: Button
var _active_filter: String = "all"
var _search_text: String = ""
var _current_radius: float = 40.0
var _raw_nearby_actors: Array[Dictionary] = []
var _filtered_actors: Array[Dictionary] = []
var _dirty_actors_set: Dictionary = { }

var _inspector_window: PanelContainer
var _label_inspector_title: Label
var _label_package_info: Label
var _option_collision_type: OptionButton
var _spin_pos_x: SpinBox
var _spin_pos_y: SpinBox
var _spin_pos_z: SpinBox
var _spin_rot_x: SpinBox
var _spin_rot_y: SpinBox
var _spin_rot_z: SpinBox
var _spin_scale_x: SpinBox
var _spin_scale_y: SpinBox
var _spin_scale_z: SpinBox
var _label_editor_status: Label
var _is_populating_fields: bool = false

var _selected_actor_name: String = ""
var _selected_actor_chunk: String = ""
var _selected_package_name: String = ""
var _selected_mesh_name: String = ""

var _water_editor_window: PanelContainer
var _label_water_chunk: Label
var _option_water_volume: OptionButton
var _spin_water_y: SpinBox
var _spin_water_center_x: SpinBox
var _spin_water_center_z: SpinBox
var _spin_water_size_x: SpinBox
var _spin_water_size_z: SpinBox
var _spin_water_ocean_ext: SpinBox
var _check_water_enabled: CheckBox
var _label_water_status: Label
var _btn_water_save: Button
var _btn_water_reset: Button
var _raw_water_volumes_dict: Dictionary = { }
var _selected_water_volume_name: String = ""
var _is_populating_water: bool = false

var _teleports_window: PanelContainer
var _teleports_list: ItemList
var _input_bookmark_name: LineEdit
var _raw_teleports: Array = []

var _hack_injector_window: PanelContainer
var _btn_hack_speed: Button
var _btn_hack_teleport: Button
var _btn_hack_noclip: Button
var _btn_hack_fly: Button
var _label_snapback_stats: Label
var _snapback_count: int = 0
var _last_snapback_reason: String = "Nenhum"
var _speedhack_active: bool = false
var _noclip_active: bool = false

# Variáveis de Estado para Arrastar Janelas (Drag & Drop)
var _dragging_window: Control = null
var _drag_mouse_offset: Vector2 = Vector2.ZERO
var _current_avatar_pos: Vector3 = Vector3.ZERO
var _current_chunk_name: String = ""


func _ready() -> void:
	_setup_ui()


func _setup_ui() -> void:
	# 1. Barra de Ferramentas do Topo (100% de largura)
	_setup_top_menu_bar()

	# 2. Janela Flutuante: World Outliner (Lista de Atores e Busca)
	_setup_outliner_window()

	# 3. Janela Flutuante: Inspetor de Propriedades do Ator
	_setup_inspector_window()

	# 4. Janela Flutuante: Editor de Volumes de Água
	_setup_water_editor_window()

	# 5. Janela Flutuante: Teleportes e Bookmarks
	_setup_teleports_window()

	# 6. Janela Flutuante: Telemetria Completa (F2)
	_setup_telemetry_window()

	# 7. Janela Flutuante: Injetor de Hacks (Test Harness)
	_setup_hack_injector_window()

# ==============================================================================
# HELPERS DE ESTILIZAÇÃO SÓLIDA (THEMING)
# ==============================================================================


func _create_flat_stylebox(
	bg_color: Color,
	border_color: Color = Color.TRANSPARENT,
	border_width: int = 0,
	corner_radius: int = 2,
) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.border_width_left = border_width
	sb.border_width_right = border_width
	sb.border_width_top = border_width
	sb.border_width_bottom = border_width
	sb.corner_radius_top_left = corner_radius
	sb.corner_radius_top_right = corner_radius
	sb.corner_radius_bottom_left = corner_radius
	sb.corner_radius_bottom_right = corner_radius
	return sb


func _style_button(btn: Button, is_accent: bool = false) -> void:
	var bg_norm = COLOR_BG_BUTTON
	var bg_hover = COLOR_BG_BUTTON_HOVER
	var bg_press = COLOR_BG_BUTTON_PRESSED
	var border = COLOR_BORDER

	if is_accent:
		bg_norm = Color(0.18, 0.28, 0.40, 1.0)
		bg_hover = Color(0.24, 0.36, 0.52, 1.0)
		bg_press = Color(0.14, 0.22, 0.32, 1.0)
		border = Color(0.35, 0.50, 0.70, 1.0)

	var sb_normal = _create_flat_stylebox(bg_norm, border, 1, 2)
	sb_normal.content_margin_left = 6.0
	sb_normal.content_margin_right = 6.0
	sb_normal.content_margin_top = 3.0
	sb_normal.content_margin_bottom = 3.0

	var sb_hover = _create_flat_stylebox(bg_hover, border, 1, 2)
	sb_hover.content_margin_left = 6.0
	sb_hover.content_margin_right = 6.0
	sb_hover.content_margin_top = 3.0
	sb_hover.content_margin_bottom = 3.0

	var sb_pressed = _create_flat_stylebox(bg_press, COLOR_BORDER_FOCUSED, 1, 2)
	sb_pressed.content_margin_left = 6.0
	sb_pressed.content_margin_right = 6.0
	sb_pressed.content_margin_top = 3.0
	sb_pressed.content_margin_bottom = 3.0

	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_stylebox_override("focus", sb_hover)
	btn.add_theme_color_override("font_color", Color(0.90, 0.92, 0.96))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))


func _style_line_edit(le: LineEdit) -> void:
	var sb_normal = _create_flat_stylebox(COLOR_BG_INPUT, COLOR_BORDER, 1, 2)
	sb_normal.content_margin_left = 6.0
	sb_normal.content_margin_right = 6.0
	sb_normal.content_margin_top = 3.0
	sb_normal.content_margin_bottom = 3.0

	var sb_focus = _create_flat_stylebox(COLOR_BG_INPUT, COLOR_BORDER_FOCUSED, 1, 2)
	sb_focus.content_margin_left = 6.0
	sb_focus.content_margin_right = 6.0
	sb_focus.content_margin_top = 3.0
	sb_focus.content_margin_bottom = 3.0

	le.add_theme_stylebox_override("normal", sb_normal)
	le.add_theme_stylebox_override("focus", sb_focus)
	le.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	le.add_theme_color_override("font_placeholder_color", COLOR_TEXT_MUTED)


func _style_item_list(il: ItemList) -> void:
	var sb_bg = _create_flat_stylebox(COLOR_BG_INPUT, COLOR_BORDER, 1, 2)
	il.add_theme_stylebox_override("panel", sb_bg)

	var sb_selected = _create_flat_stylebox(
		Color(0.20, 0.30, 0.45, 1.0),
		COLOR_BORDER_FOCUSED,
		1,
		2,
	)
	il.add_theme_stylebox_override("selected", sb_selected)
	il.add_theme_stylebox_override("selected_focus", sb_selected)
	il.add_theme_color_override("font_color", Color(0.88, 0.90, 0.95))
	il.add_theme_color_override("font_selected_color", Color(1.0, 1.0, 1.0))

# ==============================================================================
# TOP MENU BAR
# ==============================================================================


func _setup_top_menu_bar() -> void:
	_top_bar = Panel.new()
	_top_bar.name = "TopMenuBar"
	_top_bar.anchor_left = 0.0
	_top_bar.anchor_right = 1.0
	_top_bar.anchor_top = 0.0
	_top_bar.anchor_bottom = 0.0
	_top_bar.offset_bottom = TOP_BAR_HEIGHT

	var sb = _create_flat_stylebox(COLOR_BG_TOPBAR, COLOR_BORDER, 0, 0)
	sb.border_width_bottom = 1
	_top_bar.add_theme_stylebox_override("panel", sb)
	add_child(_top_bar)

	var hbox = HBoxContainer.new()
	hbox.anchor_left = 0.0
	hbox.anchor_right = 1.0
	hbox.anchor_top = 0.0
	hbox.anchor_bottom = 1.0
	hbox.offset_left = 8.0
	hbox.offset_right = -8.0
	_top_bar.add_child(hbox)

	# Menu Arquivo: Estritamente apenas "Sair do Jogo"
	_menu_file = MenuButton.new()
	_menu_file.text = "Arquivo"
	_menu_file.get_popup().add_item("Sair do Jogo", 99)
	_menu_file.get_popup().id_pressed.connect(_on_file_menu_pressed)
	_style_button(_menu_file)
	hbox.add_child(_menu_file)

	# Menu Exibir
	_menu_view = MenuButton.new()
	_menu_view.text = "Exibir"
	_menu_view.get_popup().add_item("World Outliner (F4)", 1)
	_menu_view.get_popup().add_item("Telemetria Geral (F2)", 2)
	_menu_view.get_popup().add_separator()
	_menu_view.get_popup().add_item("Wireframe do Terreno (F3)", 3)
	_menu_view.get_popup().add_item("Colisores Fisicos", 4)
	_menu_view.get_popup().add_item("Volumes de Agua", 5)
	_menu_view.get_popup().add_item("Sombras Dinamicas", 6)
	_menu_view.get_popup().id_pressed.connect(_on_view_menu_pressed)
	_style_button(_menu_view)
	hbox.add_child(_menu_view)

	# Menu Ferramentas
	_menu_tools = MenuButton.new()
	_menu_tools.text = "Ferramentas"
	_menu_tools.get_popup().add_item("Teleportes Rapidos", 1)
	_menu_tools.get_popup().add_item("Injetor de Hacks (Debug)", 4)
	_menu_tools.get_popup().add_separator()
	_menu_tools.get_popup().add_item("Alternar Modo Voo (G)", 3)
	_menu_tools.get_popup().id_pressed.connect(_on_tools_menu_pressed)
	_style_button(_menu_tools)
	hbox.add_child(_menu_tools)

	# Spacer expansor
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	# Badge de Telemetria Rapida no Canto Direito
	_label_quick_badge = Label.new()
	_label_quick_badge.text = "FPS: -- | Mem: -- | Chunk: -- | Pos: (0.0, 0.0, 0.0) | Pendencias: 0"
	_label_quick_badge.modulate = COLOR_TEXT_MUTED
	hbox.add_child(_label_quick_badge)


func _on_file_menu_pressed(id: int) -> void:
	match id:
		99:
			get_tree().quit()


func _on_view_menu_pressed(id: int) -> void:
	match id:
		1:
			toggle_actor_inspector_visibility()
		2:
			toggle_telemetry_window()
		3:
			toggle_wireframe_requested.emit()
		4:
			toggle_collisions_requested.emit()
		5:
			toggle_water_editor_window()
		6:
			toggle_shadows_requested.emit()


func _on_tools_menu_pressed(id: int) -> void:
	match id:
		1:
			toggle_teleports_window()
		3:
			# Dispara evento simulando tecla G se necessario
			pass
		4:
			toggle_hack_injector_window()

# ==============================================================================
# FABRICA DE JANELAS FLUTUANTES ARRASTAVEIS (VISUAL SOLIDO)
# ==============================================================================


func _create_window_frame(
	window_name: String,
	title_text: String,
	rect: Rect2,
	close_callable: Callable,
) -> Dictionary:
	var win = PanelContainer.new()
	win.name = window_name
	win.position = rect.position
	win.size = rect.size
	win.custom_minimum_size = rect.size

	var sb = _create_flat_stylebox(COLOR_BG_WINDOW, COLOR_BORDER, 1, 3)
	win.add_theme_stylebox_override("panel", sb)
	add_child(win)

	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 0)
	win.add_child(main_vbox)

	# Barra de Titulo (Header arrastavel)
	var title_panel = PanelContainer.new()
	var sb_title = _create_flat_stylebox(COLOR_BG_HEADER, COLOR_BORDER, 0, 3)
	sb_title.border_width_bottom = 1
	title_panel.add_theme_stylebox_override("panel", sb_title)
	main_vbox.add_child(title_panel)

	var header_hbox = HBoxContainer.new()
	header_hbox.offset_left = 8.0
	header_hbox.offset_right = -4.0
	title_panel.add_child(header_hbox)

	var title_lbl = Label.new()
	title_lbl.text = " %s" % title_text
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	header_hbox.add_child(title_lbl)

	var btn_close = Button.new()
	btn_close.text = " X "
	btn_close.flat = true
	btn_close.pressed.connect(close_callable)
	header_hbox.add_child(btn_close)

	# Registra eventos de arrasto no cabecalho
	title_panel.gui_input.connect(_on_window_header_gui_input.bind(win))

	var body_margin = MarginContainer.new()
	body_margin.add_theme_constant_override("margin_left", 8)
	body_margin.add_theme_constant_override("margin_right", 8)
	body_margin.add_theme_constant_override("margin_top", 8)
	body_margin.add_theme_constant_override("margin_bottom", 8)
	body_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(body_margin)

	var body_vbox = VBoxContainer.new()
	body_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_vbox.add_theme_constant_override("separation", 6)
	body_margin.add_child(body_vbox)

	return {
		"window": win,
		"body": body_vbox,
		"title_label": title_lbl,
	}


func _on_window_header_gui_input(event: InputEvent, window_node: Control) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging_window = window_node
			_drag_mouse_offset = window_node.global_position - get_viewport().get_mouse_position()
			window_node.move_to_front()
		else:
			_dragging_window = null


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _dragging_window:
		_dragging_window.global_position = get_viewport().get_mouse_position() + _drag_mouse_offset

# ==============================================================================
# JANELA 1: WORLD OUTLINER
# ==============================================================================


func _setup_outliner_window() -> void:
	var frame = _create_window_frame(
		"WorldOutlinerWindow",
		"World Outliner",
		Rect2(20.0, 44.0, 440.0, 560.0),
		func():
			_outliner_window.visible = false,
	)
	_outliner_window = frame["window"]
	var vbox: VBoxContainer = frame["body"]
	_outliner_window.visible = false

	# 1. Busca
	_search_input = LineEdit.new()
	_search_input.placeholder_text = "Buscar ator, modelo ou pacote..."
	_search_input.text_changed.connect(_on_search_text_changed)
	_style_line_edit(_search_input)
	vbox.add_child(_search_input)

	# 2. Abas de Categorias
	var cat_hbox = HBoxContainer.new()
	var cats = [
		["Todos", "all"],
		["Arvores", "trees"],
		["Construcoes", "buildings"],
		["Props", "props"],
		["Vegetacao", "plants"],
	]
	for c in cats:
		var btn = Button.new()
		btn.text = c[0]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_set_active_filter.bind(c[1]))
		_style_button(btn)
		cat_hbox.add_child(btn)
	vbox.add_child(cat_hbox)

	# 3. Controle de Raio
	var radius_hbox = HBoxContainer.new()
	var lbl_r = Label.new()
	lbl_r.text = "Raio de Busca:"
	lbl_r.modulate = COLOR_TEXT_MUTED
	radius_hbox.add_child(lbl_r)

	_slider_radius = HSlider.new()
	_slider_radius.min_value = 5.0
	_slider_radius.max_value = 100.0
	_slider_radius.step = 5.0
	_slider_radius.value = _current_radius
	_slider_radius.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider_radius.value_changed.connect(_on_radius_slider_changed)
	radius_hbox.add_child(_slider_radius)

	_label_radius_val = Label.new()
	_label_radius_val.text = "%dm" % int(_current_radius)
	_label_radius_val.modulate = COLOR_TEXT_ACCENT
	radius_hbox.add_child(_label_radius_val)
	vbox.add_child(radius_hbox)

	# 4. Lista de Atores
	_item_list = ItemList.new()
	_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_list.custom_minimum_size = Vector2(0, 300)
	_item_list.item_selected.connect(_on_actor_item_selected)
	_style_item_list(_item_list)
	vbox.add_child(_item_list)

	# 5. Rodape com Botoes de Lote e Contador de Modificados
	var footer_hbox = HBoxContainer.new()
	_label_outliner_footer = Label.new()
	_label_outliner_footer.text = "0 atores encontrados"
	_label_outliner_footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label_outliner_footer.modulate = COLOR_TEXT_MUTED
	footer_hbox.add_child(_label_outliner_footer)

	_btn_batch_save = Button.new()
	_btn_batch_save.text = "Salvar Todos"
	_btn_batch_save.pressed.connect(func():
			batch_save_requested.emit())
	_style_button(_btn_batch_save, true)
	footer_hbox.add_child(_btn_batch_save)

	_btn_batch_discard = Button.new()
	_btn_batch_discard.text = "Descartar"
	_btn_batch_discard.pressed.connect(func():
			batch_discard_requested.emit())
	_style_button(_btn_batch_discard)
	footer_hbox.add_child(_btn_batch_discard)

	vbox.add_child(footer_hbox)


func _on_radius_slider_changed(val: float) -> void:
	_current_radius = val
	if _label_radius_val:
		_label_radius_val.text = "%dm" % int(val)
	radius_changed.emit(val)

# ==============================================================================
# JANELA 2: INSPETOR DE PROPRIEDADES DO ATOR
# ==============================================================================


func _setup_inspector_window() -> void:
	var frame = _create_window_frame(
		"ActorInspectorWindow",
		"Propriedades do Ator",
		Rect2(470.0, 44.0, 520.0, 580.0),
		func():
			_inspector_window.visible = false,
	)
	_inspector_window = frame["window"]
	_label_inspector_title = frame["title_label"]
	var vbox: VBoxContainer = frame["body"]
	_inspector_window.visible = false

	_label_package_info = Label.new()
	_label_package_info.text = "Pacote: -- | Chave: --"
	_label_package_info.modulate = COLOR_TEXT_ACCENT
	vbox.add_child(_label_package_info)

	vbox.add_child(HSeparator.new())

	# Posicao (X, Y, Z)
	var lbl_pos = Label.new()
	lbl_pos.text = "Posicao (X, Y, Z):"
	lbl_pos.modulate = COLOR_TEXT_MUTED
	vbox.add_child(lbl_pos)

	var hbox_pos = HBoxContainer.new()
	_spin_pos_x = _create_spinbox(-999999.0, 999999.0, 0.01, 0.1, "X: ", "m")
	_spin_pos_y = _create_spinbox(-999999.0, 999999.0, 0.01, 0.1, "Y: ", "m")
	_spin_pos_z = _create_spinbox(-999999.0, 999999.0, 0.01, 0.1, "Z: ", "m")
	hbox_pos.add_child(_spin_pos_x)
	hbox_pos.add_child(_spin_pos_y)
	hbox_pos.add_child(_spin_pos_z)
	vbox.add_child(hbox_pos)

	# Rotacao (Pitch, Yaw, Roll)
	var lbl_rot = Label.new()
	lbl_rot.text = "Rotacao (Pitch, Yaw, Roll):"
	lbl_rot.modulate = COLOR_TEXT_MUTED
	vbox.add_child(lbl_rot)

	var hbox_rot = HBoxContainer.new()
	_spin_rot_x = _create_spinbox(-360.0, 360.0, 0.1, 1.0, "P: ", "°")
	_spin_rot_y = _create_spinbox(-360.0, 360.0, 0.1, 1.0, "Y: ", "°")
	_spin_rot_z = _create_spinbox(-360.0, 360.0, 0.1, 1.0, "R: ", "°")
	hbox_rot.add_child(_spin_rot_x)
	hbox_rot.add_child(_spin_rot_y)
	hbox_rot.add_child(_spin_rot_z)
	vbox.add_child(hbox_rot)

	# Botoes Rapidos de Rotacao e Ancoragem
	var rot_quick_hbox = HBoxContainer.new()
	var btn_r_minus90 = Button.new()
	btn_r_minus90.text = "-90°"
	btn_r_minus90.pressed.connect(_rotate_selected_yaw.bind(-90.0))
	_style_button(btn_r_minus90)
	rot_quick_hbox.add_child(btn_r_minus90)

	var btn_r_plus90 = Button.new()
	btn_r_plus90.text = "+90°"
	btn_r_plus90.pressed.connect(_rotate_selected_yaw.bind(90.0))
	_style_button(btn_r_plus90)
	rot_quick_hbox.add_child(btn_r_plus90)

	var btn_r_180 = Button.new()
	btn_r_180.text = "180°"
	btn_r_180.pressed.connect(_rotate_selected_yaw.bind(180.0))
	_style_button(btn_r_180)
	rot_quick_hbox.add_child(btn_r_180)

	var btn_anchor = Button.new()
	btn_anchor.text = "Ancorar ao Solo"
	btn_anchor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_anchor.pressed.connect(_anchor_selected_to_ground)
	_style_button(btn_anchor)
	rot_quick_hbox.add_child(btn_anchor)
	vbox.add_child(rot_quick_hbox)

	# Escala (X, Y, Z)
	var lbl_scale = Label.new()
	lbl_scale.text = "Escala (X, Y, Z):"
	lbl_scale.modulate = COLOR_TEXT_MUTED
	vbox.add_child(lbl_scale)

	var hbox_scale = HBoxContainer.new()
	_spin_scale_x = _create_spinbox(-100.0, 100.0, 0.01, 0.1, "X: ", "")
	_spin_scale_y = _create_spinbox(-100.0, 100.0, 0.01, 0.1, "Y: ", "")
	_spin_scale_z = _create_spinbox(-100.0, 100.0, 0.01, 0.1, "Z: ", "")
	hbox_scale.add_child(_spin_scale_x)
	hbox_scale.add_child(_spin_scale_y)
	hbox_scale.add_child(_spin_scale_z)
	vbox.add_child(hbox_scale)

	vbox.add_child(HSeparator.new())

	# Colisao Fisica (Regra Global)
	var lbl_col = Label.new()
	lbl_col.text = "Colisao Fisica (Regra Global):"
	lbl_col.modulate = COLOR_TEXT_MUTED
	vbox.add_child(lbl_col)

	var hbox_col = HBoxContainer.new()
	_option_collision_type = OptionButton.new()
	_option_collision_type.add_item("CONCAVE (Oco / Arquitetura)", 0)
	_option_collision_type.add_item("CONVEX (Solido / Caixa)", 1)
	_option_collision_type.add_item("TREE_TRUNK (Tronco Cilindrico)", 2)
	_option_collision_type.add_item("PASS_THROUGH (Sem Colisao)", 3)
	_option_collision_type.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_option_collision_type.item_selected.connect(_on_collision_option_selected)
	_style_button(_option_collision_type)
	hbox_col.add_child(_option_collision_type)

	var btn_save_col = Button.new()
	btn_save_col.text = "Salvar Regra"
	btn_save_col.pressed.connect(_on_btn_save_collision_pressed)
	_style_button(btn_save_col, true)
	hbox_col.add_child(btn_save_col)
	vbox.add_child(hbox_col)

	vbox.add_child(HSeparator.new())

	# Acoes de Persistencia
	var hbox_actions = HBoxContainer.new()
	var btn_reset = Button.new()
	btn_reset.text = "Resetar Ator"
	btn_reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_reset.pressed.connect(_on_btn_reset_pressed)
	_style_button(btn_reset)
	hbox_actions.add_child(btn_reset)

	var btn_save_single = Button.new()
	btn_save_single.text = "Salvar Fix (Individual)"
	btn_save_single.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_save_single.pressed.connect(_on_btn_save_pressed)
	_style_button(btn_save_single, true)
	hbox_actions.add_child(btn_save_single)
	vbox.add_child(hbox_actions)

	_label_editor_status = Label.new()
	_label_editor_status.text = "Selecione um ator para editar."
	_label_editor_status.modulate = COLOR_TEXT_MUTED
	vbox.add_child(_label_editor_status)


func _create_spinbox(
	min_val: float,
	max_val: float,
	step_val: float,
	arrow_step_val: float,
	prefix_str: String,
	suffix_str: String,
) -> SpinBox:
	var sb = SpinBox.new()
	sb.min_value = min_val
	sb.max_value = max_val
	sb.step = step_val
	sb.custom_arrow_step = arrow_step_val
	sb.prefix = prefix_str
	sb.suffix = suffix_str
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sb.value_changed.connect(_on_spinbox_value_changed)
	return sb


func _rotate_selected_yaw(degrees_delta: float) -> void:
	if _selected_actor_name.is_empty() or not _spin_rot_y:
		return
	var new_yaw = fmod(_spin_rot_y.value + degrees_delta, 360.0)
	_spin_rot_y.value = new_yaw


func _anchor_selected_to_ground() -> void:
	if _selected_actor_name.is_empty() or not _spin_pos_y:
		return
	if _current_avatar_pos != Vector3.ZERO:
		_spin_pos_y.value = _current_avatar_pos.y


func _create_editor_spinbox(
	min_val: float,
	max_val: float,
	step_val: float,
	arrow_step_val: float,
	suffix_str: String,
) -> SpinBox:
	var sb = SpinBox.new()
	sb.min_value = min_val
	sb.max_value = max_val
	sb.step = step_val
	sb.custom_arrow_step = arrow_step_val
	sb.suffix = suffix_str
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return sb

# ==============================================================================
# JANELA 3: EDITOR DE VOLUMES DE ÁGUA
# ==============================================================================


func _setup_water_editor_window() -> void:
	var frame = _create_window_frame(
		"WaterEditorWindow",
		"Volumes de Agua",
		Rect2(480.0, 44.0, 420.0, 480.0),
		func():
			_water_editor_window.visible = false,
	)
	_water_editor_window = frame["window"]
	var body: VBoxContainer = frame["body"]

	# Rótulo de Chunk
	_label_water_chunk = Label.new()
	_label_water_chunk.text = "Chunk Ativo: --"
	_label_water_chunk.modulate = COLOR_TEXT_ACCENT
	body.add_child(_label_water_chunk)

	# Seletor de Volume
	var lbl_vol = Label.new()
	lbl_vol.text = "Selecione o Volume de Agua:"
	lbl_vol.modulate = COLOR_TEXT_MUTED
	body.add_child(lbl_vol)

	_option_water_volume = OptionButton.new()
	_option_water_volume.item_selected.connect(_on_water_volume_selected)
	_style_button(_option_water_volume)
	body.add_child(_option_water_volume)

	# Separador
	var sep1 = HSeparator.new()
	body.add_child(sep1)

	# Grid de Campos
	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	body.add_child(grid)

	# Altitude Y (Precisão milimétrica / sub-centímetro)
	var lbl_y = Label.new()
	lbl_y.text = "Altitude (Y):"
	grid.add_child(lbl_y)
	_spin_water_y = _create_editor_spinbox(-2000.0, 2000.0, 0.001, 0.1, " m")
	_spin_water_y.value_changed.connect(_on_water_field_changed)
	grid.add_child(_spin_water_y)

	# Centro X
	var lbl_cx = Label.new()
	lbl_cx.text = "Centro X:"
	grid.add_child(lbl_cx)
	_spin_water_center_x = _create_editor_spinbox(-20000.0, 20000.0, 0.01, 1.0, " m")
	_spin_water_center_x.value_changed.connect(_on_water_field_changed)
	grid.add_child(_spin_water_center_x)

	# Centro Z
	var lbl_cz = Label.new()
	lbl_cz.text = "Centro Z:"
	grid.add_child(lbl_cz)
	_spin_water_center_z = _create_editor_spinbox(-20000.0, 20000.0, 0.01, 1.0, " m")
	_spin_water_center_z.value_changed.connect(_on_water_field_changed)
	grid.add_child(_spin_water_center_z)

	# Tamanho X
	var lbl_sx = Label.new()
	lbl_sx.text = "Largura (X):"
	grid.add_child(lbl_sx)
	_spin_water_size_x = _create_editor_spinbox(1.0, 50000.0, 0.01, 1.0, " m")
	_spin_water_size_x.value_changed.connect(_on_water_field_changed)
	grid.add_child(_spin_water_size_x)

	# Tamanho Z
	var lbl_sz = Label.new()
	lbl_sz.text = "Comprimento (Z):"
	grid.add_child(lbl_sz)
	_spin_water_size_z = _create_editor_spinbox(1.0, 50000.0, 0.01, 1.0, " m")
	_spin_water_size_z.value_changed.connect(_on_water_field_changed)
	grid.add_child(_spin_water_size_z)

	# Extensão Oceano
	var lbl_ext = Label.new()
	lbl_ext.text = "Extensao Oceano:"
	grid.add_child(lbl_ext)
	_spin_water_ocean_ext = _create_editor_spinbox(0.0, 100000.0, 0.01, 10.0, " m")
	_spin_water_ocean_ext.value_changed.connect(_on_water_field_changed)
	grid.add_child(_spin_water_ocean_ext)

	# Habilitado CheckBox
	_check_water_enabled = CheckBox.new()
	_check_water_enabled.text = "Volume Habilitado / Visivel"
	_check_water_enabled.button_pressed = true
	_check_water_enabled.toggled.connect(func(_val):
			_on_water_field_changed(0.0))
	body.add_child(_check_water_enabled)

	# Separador
	var sep2 = HSeparator.new()
	body.add_child(sep2)

	# Botões de Ação
	var btn_hbox = HBoxContainer.new()
	btn_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_hbox.add_theme_constant_override("separation", 6)
	body.add_child(btn_hbox)

	_btn_water_reset = Button.new()
	_btn_water_reset.text = "Resetar Original"
	_btn_water_reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_water_reset.pressed.connect(_on_btn_water_reset_pressed)
	_style_button(_btn_water_reset)
	btn_hbox.add_child(_btn_water_reset)

	_btn_water_save = Button.new()
	_btn_water_save.text = "Salvar Fix"
	_btn_water_save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_water_save.pressed.connect(_on_btn_water_save_pressed)
	_style_button(_btn_water_save, true)
	btn_hbox.add_child(_btn_water_save)

	# Status
	_label_water_status = Label.new()
	_label_water_status.text = "Status: Pronto"
	_label_water_status.modulate = COLOR_TEXT_MUTED
	body.add_child(_label_water_status)

	_water_editor_window.visible = false


func populate_water_volumes(chunk_name: String, water_data: Dictionary) -> void:
	_is_populating_water = true
	_current_chunk_name = chunk_name
	_raw_water_volumes_dict = water_data
	if _label_water_chunk:
		_label_water_chunk.text = "Chunk Ativo: %s" % chunk_name

	if _option_water_volume:
		_option_water_volume.clear()
		var vols = water_data.get("water_volumes", { })
		if vols is Dictionary and not vols.is_empty():
			var idx = 0
			for v_name in vols.keys():
				var v = vols[v_name]
				var d_name = str(v.get("name", v_name)) if (v is Dictionary) else str(v_name)
				_option_water_volume.add_item("%s (%s)" % [d_name, v_name], idx)
				idx += 1
			_option_water_volume.selected = 0
			_on_water_volume_selected(0)
		else:
			_option_water_volume.add_item("Nenhum volume de agua", 0)
			_selected_water_volume_name = ""
			if _label_water_status:
				_label_water_status.text = "Nenhum volume de agua neste chunk."
				_label_water_status.modulate = COLOR_TEXT_MUTED

	_is_populating_water = false


func _on_water_volume_selected(idx: int) -> void:
	var vols = _raw_water_volumes_dict.get("water_volumes", { })
	if not (vols is Dictionary) or idx < 0 or idx >= vols.size():
		return

	var keys = vols.keys()
	_selected_water_volume_name = keys[idx]
	var v = vols[_selected_water_volume_name]
	if not (v is Dictionary):
		return

	_is_populating_water = true
	var surface_y = float(v.get("water_plane_height_m", v.get("surface_y_m", -320.0)))
	var center_arr = v.get("center_m", [0.0, 0.0])
	var size_arr = v.get("size_m", [2621.44, 2621.44])
	var c_x = float(center_arr[0]) if center_arr.size() > 0 else 0.0
	var c_z = float(center_arr[1]) if center_arr.size() > 1 else 0.0
	var s_x = float(size_arr[0]) if size_arr.size() > 0 else 2621.44
	var s_z = float(size_arr[1]) if size_arr.size() > 1 else 2621.44
	var ocean_ext = float(v.get("ocean_extension", 0.0))
	var is_enabled = v.get("enabled", true)

	if _spin_water_y:
		_spin_water_y.value = surface_y
	if _spin_water_center_x:
		_spin_water_center_x.value = c_x
	if _spin_water_center_z:
		_spin_water_center_z.value = c_z
	if _spin_water_size_x:
		_spin_water_size_x.value = s_x
	if _spin_water_size_z:
		_spin_water_size_z.value = s_z
	if _spin_water_ocean_ext:
		_spin_water_ocean_ext.value = ocean_ext
	if _check_water_enabled:
		_check_water_enabled.button_pressed = is_enabled

	_is_populating_water = false
	if _label_water_status:
		_label_water_status.text = "Volume '%s' selecionado." % _selected_water_volume_name
		_label_water_status.modulate = COLOR_TEXT_MUTED


func _on_water_field_changed(_val: float) -> void:
	if _is_populating_water or _selected_water_volume_name.is_empty():
		return

	var data = {
		"water_plane_height_m": _spin_water_y.value if _spin_water_y else -320.0,
		"surface_y_m": _spin_water_y.value if _spin_water_y else -320.0,
		"center_m": [
			_spin_water_center_x.value if _spin_water_center_x else 0.0,
			_spin_water_center_z.value if _spin_water_center_z else 0.0,
		],
		"size_m": [
			_spin_water_size_x.value if _spin_water_size_x else 2621.44,
			_spin_water_size_z.value if _spin_water_size_z else 2621.44,
		],
		"ocean_extension": _spin_water_ocean_ext.value if _spin_water_ocean_ext else 0.0,
		"enabled": _check_water_enabled.button_pressed if _check_water_enabled else true,
	}

	water_volume_transform_applied.emit(_current_chunk_name, _selected_water_volume_name, data)
	if _label_water_status:
		_label_water_status.text = "Volume atualizado em tempo real (nao salvo)"
		_label_water_status.modulate = COLOR_TEXT_WARN


func _on_btn_water_save_pressed() -> void:
	if _selected_water_volume_name.is_empty() or _current_chunk_name.is_empty():
		return

	var data = {
		"water_plane_height_m": _spin_water_y.value if _spin_water_y else -320.0,
		"surface_y_m": _spin_water_y.value if _spin_water_y else -320.0,
		"center_m": [
			_spin_water_center_x.value if _spin_water_center_x else 0.0,
			_spin_water_center_z.value if _spin_water_center_z else 0.0,
		],
		"size_m": [
			_spin_water_size_x.value if _spin_water_size_x else 2621.44,
			_spin_water_size_z.value if _spin_water_size_z else 2621.44,
		],
		"ocean_extension": _spin_water_ocean_ext.value if _spin_water_ocean_ext else 0.0,
		"enabled": _check_water_enabled.button_pressed if _check_water_enabled else true,
	}

	water_volume_fix_saved.emit(_current_chunk_name, _selected_water_volume_name, data)
	if _label_water_status:
		_label_water_status.text = "Fix de agua salvo em water_volumes_fix.json!"
		_label_water_status.modulate = COLOR_TEXT_SUCCESS


func _on_btn_water_reset_pressed() -> void:
	if _selected_water_volume_name.is_empty() or _current_chunk_name.is_empty():
		return

	water_volume_reset_requested.emit(_current_chunk_name, _selected_water_volume_name)
	if _label_water_status:
		_label_water_status.text = "Volume resetado para os valores originais RAW."
		_label_water_status.modulate = COLOR_TEXT_MUTED

# ==============================================================================
# JANELA 4: TELEPORTES E BOOKMARKS
# ==============================================================================


func _setup_teleports_window() -> void:
	var frame = _create_window_frame(
		"TeleportsWindow",
		"Teleportes Rapidos",
		Rect2(20.0, 610.0, 440.0, 260.0),
		func():
			_teleports_window.visible = false,
	)
	_teleports_window = frame["window"]
	var vbox: VBoxContainer = frame["body"]
	_teleports_window.visible = false

	_teleports_list = ItemList.new()
	_teleports_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_teleports_list.item_activated.connect(_on_teleport_item_activated)
	_style_item_list(_teleports_list)
	vbox.add_child(_teleports_list)

	var hbox_nav = HBoxContainer.new()
	hbox_nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox_nav)

	var btn_tp = Button.new()
	btn_tp.text = "Teleportar"
	btn_tp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_tp.pressed.connect(_on_btn_teleport_pressed)
	_style_button(btn_tp, true)
	hbox_nav.add_child(btn_tp)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var act_hbox = HBoxContainer.new()
	act_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_input_bookmark_name = LineEdit.new()
	_input_bookmark_name.placeholder_text = "Nome do bookmark (ex: Torre Sul)"
	_input_bookmark_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_line_edit(_input_bookmark_name)
	act_hbox.add_child(_input_bookmark_name)

	var btn_add_bk = Button.new()
	btn_add_bk.text = "Salvar Atual"
	btn_add_bk.pressed.connect(_on_btn_add_bookmark_pressed)
	_style_button(btn_add_bk)
	act_hbox.add_child(btn_add_bk)
	vbox.add_child(act_hbox)


func load_teleports(list: Array) -> void:
	_raw_teleports = list
	if not _teleports_list:
		return
	_teleports_list.clear()
	for entry in _raw_teleports:
		if entry is Dictionary:
			var t_name = entry.get("name", "Local")
			var c_name = entry.get("chunk_name", "")
			_teleports_list.add_item("%s [%s]" % [t_name, c_name])


func _on_teleport_item_activated(idx: int) -> void:
	_teleport_to_index(idx)


func _on_btn_teleport_pressed() -> void:
	if not _teleports_list:
		return
	var sel = _teleports_list.get_selected_items()
	if sel.size() > 0:
		_teleport_to_index(sel[0])


func _teleport_to_index(idx: int) -> void:
	if idx >= 0 and idx < _raw_teleports.size():
		var entry = _raw_teleports[idx]
		var pos_arr = entry.get("position", [])
		if pos_arr.size() >= 3:
			var target = Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))
			teleport_requested.emit(target)


func _on_btn_add_bookmark_pressed() -> void:
	if not _input_bookmark_name:
		return
	var b_name = _input_bookmark_name.text.strip_edges()
	if b_name.is_empty():
		b_name = "Ponto_%d" % (_raw_teleports.size() + 1)
	bookmark_save_requested.emit(b_name, _current_avatar_pos, _current_chunk_name)
	_input_bookmark_name.text = ""

# ==============================================================================
# JANELA 5: TELEMETRIA COMPLETA (F2)
# ==============================================================================


func _setup_telemetry_window() -> void:
	var frame = _create_window_frame(
		"TelemetryWindow",
		"Telemetria & Diagnostico Tecnico (F2)",
		Rect2(20.0, 44.0, 480.0, 430.0),
		func():
			_telemetry_window.visible = false,
	)
	_telemetry_window = frame["window"]
	_label_telemetry_body = Label.new()
	_label_telemetry_body.text = "Coletando metricas de desempenho..."
	_label_telemetry_body.modulate = Color(0.92, 0.94, 0.98)
	frame["body"].add_child(_label_telemetry_body)
	_telemetry_window.visible = false

# ==============================================================================
# JANELA 6: INJETOR DE HACKS / TEST HARNESS ANTI-CHEAT
# ==============================================================================


func _setup_hack_injector_window() -> void:
	var frame = _create_window_frame(
		"HackInjectorWindow",
		"Injetor de Hacks (Test Harness)",
		Rect2(20.0, 480.0, 440.0, 270.0),
		func():
			_hack_injector_window.visible = false,
	)
	_hack_injector_window = frame["window"]
	var vbox: VBoxContainer = frame["body"]
	_hack_injector_window.visible = false

	var lbl_desc = Label.new()
	lbl_desc.text = "Injecao controlada de anomalias para auditoria de autoridade:"
	lbl_desc.modulate = COLOR_TEXT_MUTED
	vbox.add_child(lbl_desc)

	# Grid de Botões de Ação
	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(grid)

	_btn_hack_speed = Button.new()
	_btn_hack_speed.text = "Speedhack x5 [OFF]"
	_btn_hack_speed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_hack_speed.pressed.connect(_on_btn_hack_speed_pressed)
	_style_button(_btn_hack_speed)
	grid.add_child(_btn_hack_speed)

	_btn_hack_teleport = Button.new()
	_btn_hack_teleport.text = "Teleporte (+30m)"
	_btn_hack_teleport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_hack_teleport.pressed.connect(_on_btn_hack_teleport_pressed)
	_style_button(_btn_hack_teleport)
	grid.add_child(_btn_hack_teleport)

	_btn_hack_noclip = Button.new()
	_btn_hack_noclip.text = "No-Clip [OFF]"
	_btn_hack_noclip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_hack_noclip.pressed.connect(_on_btn_hack_noclip_pressed)
	_style_button(_btn_hack_noclip)
	grid.add_child(_btn_hack_noclip)

	_btn_hack_fly = Button.new()
	_btn_hack_fly.text = "Flyhack (+15m)"
	_btn_hack_fly.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_hack_fly.pressed.connect(_on_btn_hack_fly_pressed)
	_style_button(_btn_hack_fly)
	grid.add_child(_btn_hack_fly)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Painel de Resumo de Interceptações (Snapbacks)
	_label_snapback_stats = Label.new()
	_label_snapback_stats.text = "Snapbacks Interceptados: 0\nUltimo Motivo: Nenhum\nStatus Anti-Cheat: Monitorando autoridade"
	_label_snapback_stats.modulate = COLOR_TEXT_ACCENT
	vbox.add_child(_label_snapback_stats)


func _on_btn_hack_speed_pressed() -> void:
	_speedhack_active = not _speedhack_active
	if _btn_hack_speed:
		_btn_hack_speed.text = "Speedhack x5 [ON]" if _speedhack_active else "Speedhack x5 [OFF]"
		_btn_hack_speed.modulate = COLOR_TEXT_WARN if _speedhack_active else Color.WHITE
	speedhack_toggled.emit(_speedhack_active)


func _on_btn_hack_teleport_pressed() -> void:
	force_teleport_requested.emit(30.0)


func _on_btn_hack_noclip_pressed() -> void:
	_noclip_active = not _noclip_active
	if _btn_hack_noclip:
		_btn_hack_noclip.text = "No-Clip [ON]" if _noclip_active else "No-Clip [OFF]"
		_btn_hack_noclip.modulate = COLOR_TEXT_WARN if _noclip_active else Color.WHITE
	noclip_toggled.emit(_noclip_active)


func _on_btn_hack_fly_pressed() -> void:
	flyhack_requested.emit(15.0)


func increment_snapback_counter(reason: String = "") -> void:
	_snapback_count += 1
	if not reason.is_empty():
		_last_snapback_reason = reason
	if _label_snapback_stats:
		_label_snapback_stats.text = "Snapbacks Interceptados: %d\nUltimo Motivo: %s\nStatus Anti-Cheat: Correcao aplicada pelo servidor!" % [
			_snapback_count,
			_last_snapback_reason,
		]
		_label_snapback_stats.modulate = COLOR_TEXT_WARN


# ==============================================================================
# GERENCIAMENTO E CONTROLE DE VISIBILIDADE EM CASCATA (ESC)
# ==============================================================================


func close_topmost_window() -> bool:
	if _inspector_window and _inspector_window.visible:
		_inspector_window.visible = false
		actor_selected.emit({ })
		return true
	if _water_editor_window and _water_editor_window.visible:
		_water_editor_window.visible = false
		return true
	if _hack_injector_window and _hack_injector_window.visible:
		_hack_injector_window.visible = false
		return true
	if _teleports_window and _teleports_window.visible:
		_teleports_window.visible = false
		return true
	if _outliner_window and _outliner_window.visible:
		_outliner_window.visible = false
		return true
	if _telemetry_window and _telemetry_window.visible:
		_telemetry_window.visible = false
		return true
	return false


func toggle_visibility() -> void:
	visible = not visible


func toggle_actor_inspector_visibility() -> void:
	if _outliner_window:
		_outliner_window.visible = not _outliner_window.visible
		if _outliner_window.visible:
			_outliner_window.move_to_front()


func toggle_water_editor_window() -> void:
	if _water_editor_window:
		_water_editor_window.visible = not _water_editor_window.visible
		if _water_editor_window.visible:
			_water_editor_window.move_to_front()
			water_volumes_refresh_requested.emit(_current_chunk_name)


func toggle_teleports_window() -> void:
	if _teleports_window:
		_teleports_window.visible = not _teleports_window.visible
		if _teleports_window.visible:
			_teleports_window.move_to_front()


func toggle_telemetry_window() -> void:
	if _telemetry_window:
		_telemetry_window.visible = not _telemetry_window.visible
		if _telemetry_window.visible:
			_telemetry_window.move_to_front()


func toggle_hack_injector_window() -> void:
	if _hack_injector_window:
		_hack_injector_window.visible = not _hack_injector_window.visible
		if _hack_injector_window.visible:
			_hack_injector_window.move_to_front()


func is_actor_inspector_open() -> bool:
	return (
		(_outliner_window and _outliner_window.visible)
		or (_inspector_window and _inspector_window.visible)
	)


func is_mouse_over_ui() -> bool:
	if not visible:
		return false
	var m_pos = get_viewport().get_mouse_position()

	# Top Bar
	if _top_bar and _top_bar.visible and _top_bar.get_global_rect().has_point(m_pos):
		return true

	# Janelas ativas
	var wins = [
		_outliner_window,
		_inspector_window,
		_water_editor_window,
		_teleports_window,
		_telemetry_window,
		_hack_injector_window,
	]
	for w in wins:
		if w and w.visible and w.get_global_rect().has_point(m_pos):
			return true

	return false

# ==============================================================================
# ATUALIZACAO DE DADOS E TELEMETRIA
# ==============================================================================


func update_telemetry(
	avatar_pos: Vector3,
	chunk_name: String,
	is_wireframe: bool = false,
	ground_altitude: float = 0.0,
	is_flying: bool = false,
	streaming_stats: Dictionary = { },
	net_stats: Dictionary = { },
) -> void:
	_current_avatar_pos = avatar_pos
	_current_chunk_name = chunk_name

	var fps = Engine.get_frames_per_second()
	var mem_mb = OS.get_static_memory_usage() / BYTES_TO_MB
	var dirty_count = _dirty_actors_set.size()

	# Atualiza badge da Top Bar com contagem exata de pendencias
	if _label_quick_badge:
		_label_quick_badge.text = "FPS: %d | Mem: %.1f MB | Chunk: %s | Pos: (%.1f, %.1f, %.1f)m | Pendencias: %d" % [
			fps,
			mem_mb,
			chunk_name,
			avatar_pos.x,
			avatar_pos.y,
			avatar_pos.z,
			dirty_count,
		]

	# Atualiza janela de telemetria completa com diagnóstico avançado
	if _label_telemetry_body and _telemetry_window and _telemetry_window.visible:
		var cpu_process_ms = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var cpu_physics_ms = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		var draw_calls = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var primitives = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		var vram_total_mb = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / BYTES_TO_MB
		var vram_tex_mb = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / BYTES_TO_MB
		var vram_buf_mb = Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / BYTES_TO_MB

		var nodes_count = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		var resources_count = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
		var col_pairs = int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS))

		var active_chunks = streaming_stats.get("active_chunks", 0)
		var total_static_actors = streaming_stats.get("total_static_actors", 0)

		var cache_stats = RuntimeAssetCacheClass.get_cache_stats()
		var tex_cached = cache_stats.get("textures", 0)
		var mesh_cached = cache_stats.get("meshes", 0)
		var shape_cached = cache_stats.get("convex_shapes", 0) + cache_stats.get(
			"trimesh_shapes",
			0,
		)

		var net_status = net_stats.get("status", "Modo Editor / Standalone")
		var ping_ms = net_stats.get("ping_ms", 0.0)
		var avg_ping_ms = net_stats.get("avg_ping_ms", 0.0)
		var loss_pct = net_stats.get("loss_pct", 0.0)
		var net_in_kb = net_stats.get("rx_kbps", 0.0)
		var net_out_kb = net_stats.get("tx_kbps", 0.0)

		var prim_str = "%.1f K" % (primitives / 1000.0) if primitives >= 1000 else str(primitives)
		var frametime_ms = 1000.0 / maxf(float(fps), 1.0)

		_label_telemetry_body.text = (
			"=== RENDERIZACAO & GPU ===\n"
			+ "  Frametime:      %.1f ms (CPU: %.2fms | Physics: %.2fms) | %d FPS\n"
			% [frametime_ms, cpu_process_ms, cpu_physics_ms, fps]
			+ "  Draw Calls:     %d chamadas de desenho\n" % draw_calls
			+ "  Triangulos:     %s primitivas na cena\n" % prim_str
			+ "  Memoria VRAM:   %.1f MB (Texturas: %.1f MB | Buffers: %.1f MB)\n\n"
			% [vram_total_mb, vram_tex_mb, vram_buf_mb]
			+ "=== MUNDO & STREAMING ===\n"
			+ "  Chunk Ativo:    %s | Altura Solo: %.1f m\n" % [chunk_name, ground_altitude]
			+ "  Chunks Vivos:   %d em memoria | Atores: %d instancias\n"
			% [active_chunks, total_static_actors]
			+ "  Asset Cache:    %d texturas | %d malhas | %d formas colisor\n"
			% [tex_cached, mesh_cached, shape_cached]
			+ "  Modo / Wire:    %s | %s | Pendencias: %d\n\n"
			% [
				"[VOO]" if is_flying else "[SOLO]",
				"[WIREFRAME]" if is_wireframe else "[SOLIDO]",
				dirty_count,
			]
			+ "=== ENGINE & FISICA ===\n"
			+ "  Cena Godot:     %d nos vivos | %d recursos carregados\n"
			% [nodes_count, resources_count]
			+ "  Pares Colisao:  %d pares ativos no servidor 3D\n\n" % col_pairs
			+ "=== REDE (QuanticNet) - Bare-Metal UDP ===\n"
			+ "  Status Sessao:  %s\n" % net_status
			+ "  Latencia (RTT): Atual: %.1f ms | Media: %.1f ms | Perda: %.1f%%\n"
			% [ping_ms, avg_ping_ms, loss_pct]
			+ "  Trafego Rede:   ↓ %.1f KB/s | ↑ %.1f KB/s\n"
			% [net_in_kb, net_out_kb]
			+ "---------------------------------------------------\n"
			+ "[F2] Telemetria  | [F3] Wireframe  | [F4] Outliner  | [G] Voo  | [ESC] Sair"
		)


func update_pending_summary(summary: Dictionary) -> void:
	_dirty_actors_set = summary.get("dirty_set", { })
	_apply_filters_and_refresh_list()
	_update_inspector_dirty_status()


func _update_inspector_dirty_status() -> void:
	if _selected_actor_name.is_empty() or not _label_inspector_title:
		return
	var is_dirty = _dirty_actors_set.has(_selected_actor_name)
	if is_dirty:
		_label_inspector_title.text = "* Propriedades: %s [%s] (Nao Salvo)" % [
			_selected_actor_name,
			_selected_actor_chunk,
		]
		_label_inspector_title.modulate = COLOR_TEXT_WARN
	else:
		_label_inspector_title.text = "Propriedades: %s [%s]" % [
			_selected_actor_name,
			_selected_actor_chunk,
		]
		_label_inspector_title.modulate = Color(0.92, 0.95, 1.0)


func update_nearby_actors(
	actors: Array[Dictionary],
	radius: float,
	_center_pos: Vector3 = Vector3.ZERO,
) -> void:
	_raw_nearby_actors = actors
	_current_radius = radius
	if _slider_radius and _slider_radius.value != radius:
		_slider_radius.value = radius
	if _label_radius_val:
		_label_radius_val.text = "%dm" % int(radius)
	_apply_filters_and_refresh_list()


func _on_search_text_changed(new_text: String) -> void:
	_search_text = new_text.strip_edges().to_lower()
	_apply_filters_and_refresh_list()


func _set_active_filter(filter_name: String) -> void:
	_active_filter = filter_name
	_apply_filters_and_refresh_list()


func _apply_filters_and_refresh_list() -> void:
	if not _item_list:
		return

	_filtered_actors.clear()
	_item_list.clear()

	for actor in _raw_nearby_actors:
		var actor_name = actor.get("actor_name", "")
		var mesh_name = actor.get("mesh_name", "")
		var pkg_name = actor.get("package_name", "")
		var c_type = actor.get("classification_type", "convex").to_lower()

		# Filtro por Categoria
		var match_cat = true
		match _active_filter:
			"trees":
				match_cat = "tree_trunk" in c_type or "tree" in mesh_name.to_lower()
			"buildings":
				match_cat = (
					c_type == "concave" or "house" in mesh_name.to_lower()
					or "wall" in mesh_name.to_lower() or "gate" in mesh_name.to_lower()
				)
			"props":
				match_cat = c_type == "convex"
			"plants":
				match_cat = c_type == "pass_through"

		if not match_cat:
			continue

		# Filtro de Busca Textual
		if not _search_text.is_empty():
			var full_str = ("%s %s %s" % [actor_name, mesh_name, pkg_name]).to_lower()
			if not (_search_text in full_str):
				continue

		_filtered_actors.append(actor)

		var dist = float(actor.get("distance", 0.0))
		var is_dirty = _dirty_actors_set.has(actor_name)
		var dirty_prefix = "* " if is_dirty else ""
		var label = "%s[%.1fm] %s [%s] | %s" % [
			dirty_prefix,
			dist,
			actor_name,
			actor.get("chunk_name", ""),
			mesh_name,
		]
		var idx = _item_list.add_item(label)
		if is_dirty:
			_item_list.set_item_custom_fg_color(idx, COLOR_TEXT_WARN)

	var dirty_count = _dirty_actors_set.size()
	if _label_outliner_footer:
		if dirty_count > 0:
			_label_outliner_footer.text = "%d atores encontrados | %d alterado(s) nao salvo(s)" % [
				_filtered_actors.size(),
				dirty_count,
			]
		else:
			_label_outliner_footer.text = "%d atores encontrados" % _filtered_actors.size()

	if _btn_batch_save:
		if dirty_count > 0:
			_btn_batch_save.text = "Salvar Todos (%d)" % dirty_count
		else:
			_btn_batch_save.text = "Salvar Todos"


func _on_actor_item_selected(index: int) -> void:
	if index >= 0 and index < _filtered_actors.size():
		var actor_data = _filtered_actors[index]
		show_inspected_actor_details(actor_data)


func show_inspected_actor_details(actor_data: Dictionary) -> void:
	_selected_actor_name = actor_data.get("actor_name", "")
	_selected_actor_chunk = actor_data.get("chunk_name", "")
	_selected_package_name = actor_data.get("package_name", "")
	_selected_mesh_name = actor_data.get("mesh_name", "")

	if _inspector_window:
		_inspector_window.visible = true
		_inspector_window.move_to_front()

	_update_inspector_dirty_status()

	var full_key = "%s.%s" % [_selected_package_name, _selected_mesh_name] if not _selected_package_name.is_empty() else _selected_mesh_name
	if _label_package_info:
		_label_package_info.text = "Pacote: %s | Chave: %s" % [_selected_package_name, full_key]

	var c_type = actor_data.get("classification_type", "convex").to_lower()
	if _option_collision_type:
		if "tree_trunk" in c_type:
			_option_collision_type.selected = 2
		elif c_type == "concave":
			_option_collision_type.selected = 0
		elif c_type == "pass_through":
			_option_collision_type.selected = 3
		else:
			_option_collision_type.selected = 1

	var pos_arg = actor_data.get("position", Vector3.ZERO)
	var rot_arg = actor_data.get("rotation_degrees", Vector3.ZERO)
	var scl_arg = actor_data.get("scale", Vector3.ONE)

	var is_dirty = _dirty_actors_set.has(_selected_actor_name)
	var status_msg = "Ator possui alteracoes pendentes de salvamento." if is_dirty else "Ator selecionado para edicao."
	set_editor_values(pos_arg, rot_arg, scl_arg, status_msg)
	actor_selected.emit(actor_data)


func _on_spinbox_value_changed(_val: float) -> void:
	if _is_populating_fields or _selected_actor_name.is_empty():
		return
	var pos = Vector3(_spin_pos_x.value, _spin_pos_y.value, _spin_pos_z.value)
	var rot = Vector3(_spin_rot_x.value, _spin_rot_y.value, _spin_rot_z.value)
	var sc = Vector3(_spin_scale_x.value, _spin_scale_y.value, _spin_scale_z.value)
	_dirty_actors_set[_selected_actor_name] = true
	actor_transform_applied.emit(_selected_actor_name, pos, rot, sc, _selected_actor_chunk)
	_update_inspector_dirty_status()
	_apply_filters_and_refresh_list()
	if _label_editor_status:
		_label_editor_status.text = "Alteracao pendente (nao salva)"
		_label_editor_status.modulate = COLOR_TEXT_WARN


func _on_collision_option_selected(idx: int) -> void:
	if _selected_actor_name.is_empty() or not _option_collision_type:
		return
	var type_str = "convex"
	match idx:
		0:
			type_str = "concave"
		1:
			type_str = "convex"
		2:
			type_str = "tree_trunk"
		3:
			type_str = "pass_through"
	actor_collision_changed.emit(
		_selected_actor_name,
		type_str,
		_selected_actor_chunk,
		_selected_package_name,
		_selected_mesh_name,
	)
	if _label_editor_status:
		_label_editor_status.text = "Colisor alterado para %s" % type_str.to_upper()
		_label_editor_status.modulate = COLOR_TEXT_ACCENT


func _on_btn_save_collision_pressed() -> void:
	if _selected_mesh_name.is_empty() or not _option_collision_type:
		return
	var type_str = "convex"
	match _option_collision_type.selected:
		0:
			type_str = "concave"
		1:
			type_str = "convex"
		2:
			type_str = "tree_trunk"
		3:
			type_str = "pass_through"

	actor_collision_save_requested.emit(_selected_package_name, _selected_mesh_name, type_str)
	if _label_editor_status:
		_label_editor_status.text = "Regra de colisao salva no JSON global"
		_label_editor_status.modulate = COLOR_TEXT_SUCCESS


func _on_btn_save_pressed() -> void:
	if _selected_actor_name.is_empty():
		return
	var pos = Vector3(_spin_pos_x.value, _spin_pos_y.value, _spin_pos_z.value)
	var rot = Vector3(_spin_rot_x.value, _spin_rot_y.value, _spin_rot_z.value)
	var sc = Vector3(_spin_scale_x.value, _spin_scale_y.value, _spin_scale_z.value)
	_dirty_actors_set.erase(_selected_actor_name)
	actor_fix_saved.emit(_selected_actor_name, pos, rot, sc, _selected_actor_chunk)
	_update_inspector_dirty_status()
	_apply_filters_and_refresh_list()
	if _label_editor_status:
		_label_editor_status.text = "Alteracoes salvas no JSON do chunk"
		_label_editor_status.modulate = COLOR_TEXT_SUCCESS


func _on_btn_reset_pressed() -> void:
	if _selected_actor_name.is_empty():
		return
	_dirty_actors_set.erase(_selected_actor_name)
	actor_reset_requested.emit(_selected_actor_name, _selected_actor_chunk)
	_update_inspector_dirty_status()
	_apply_filters_and_refresh_list()


func set_editor_values(
	pos: Variant,
	rot_deg: Variant,
	sc: Variant,
	status_msg: String = "",
) -> void:
	_is_populating_fields = true
	if pos is Array and pos.size() >= 3:
		if _spin_pos_x:
			_spin_pos_x.value = float(pos[0])
		if _spin_pos_y:
			_spin_pos_y.value = float(pos[1])
		if _spin_pos_z:
			_spin_pos_z.value = float(pos[2])
	elif pos is Vector3:
		if _spin_pos_x:
			_spin_pos_x.value = pos.x
		if _spin_pos_y:
			_spin_pos_y.value = pos.y
		if _spin_pos_z:
			_spin_pos_z.value = pos.z

	if rot_deg is Array and rot_deg.size() >= 3:
		if _spin_rot_x:
			_spin_rot_x.value = float(rot_deg[0])
		if _spin_rot_y:
			_spin_rot_y.value = float(rot_deg[1])
		if _spin_rot_z:
			_spin_rot_z.value = float(rot_deg[2])
	elif rot_deg is Vector3:
		if _spin_rot_x:
			_spin_rot_x.value = rot_deg.x
		if _spin_rot_y:
			_spin_rot_y.value = rot_deg.y
		if _spin_rot_z:
			_spin_rot_z.value = rot_deg.z

	if sc is Array and sc.size() >= 3:
		if _spin_scale_x:
			_spin_scale_x.value = float(sc[0])
		if _spin_scale_y:
			_spin_scale_y.value = float(sc[1])
		if _spin_scale_z:
			_spin_scale_z.value = float(sc[2])
	elif sc is Vector3:
		if _spin_scale_x:
			_spin_scale_x.value = sc.x
		if _spin_scale_y:
			_spin_scale_y.value = sc.y
		if _spin_scale_z:
			_spin_scale_z.value = sc.z

	_is_populating_fields = false
	if _label_editor_status and not status_msg.is_empty():
		_label_editor_status.text = status_msg
		_label_editor_status.modulate = COLOR_TEXT_WARN if _dirty_actors_set.has(
			_selected_actor_name
		) else COLOR_TEXT_MUTED


func get_current_position() -> Vector3:
	return Vector3(
		_spin_pos_x.value if _spin_pos_x else 0.0,
		_spin_pos_y.value if _spin_pos_y else 0.0,
		_spin_pos_z.value if _spin_pos_z else 0.0,
	)


func get_current_rotation() -> Vector3:
	return Vector3(
		_spin_rot_x.value if _spin_rot_x else 0.0,
		_spin_rot_y.value if _spin_rot_y else 0.0,
		_spin_rot_z.value if _spin_rot_z else 0.0,
	)


func get_current_scale() -> Vector3:
	return Vector3(
		_spin_scale_x.value if _spin_scale_x else 1.0,
		_spin_scale_y.value if _spin_scale_y else 1.0,
		_spin_scale_z.value if _spin_scale_z else 1.0,
	)
