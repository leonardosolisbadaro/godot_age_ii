## @file debug_hud.gd
## @path res://src/infrastructure/debug_hud.gd
##
## @description
## Camada de interface de depuração (CanvasLayer) exibindo telemetria em tempo real
## de coordenadas mundiais, chunk ativo, FPS, memória e modo de renderização wireframe (F2).
##
## @created 2026-08-19
## @updated 2026-08-20
##
## @author Leonardo S. Badaró
extends CanvasLayer

# ==============================================================================
# CONSTANTES SEMÂNTICAS DE INTERFACE
# ==============================================================================

## @const PANEL_POSITION (Vector2)
## O que: Posição do painel principal de telemetria no canto superior esquerdo (20px, 20px).
## Porque: Posição desobstruída para dados em tempo real.
const PANEL_POSITION: Vector2 = Vector2(20.0, 20.0)

## @const PANEL_SIZE (Vector2)
## O que: Dimensão do painel principal de telemetria (340px x 240px).
## Porque: Enquadramento vertical para dados de status e atalhos linha por linha.
const PANEL_SIZE: Vector2 = Vector2(340.0, 240.0)

## @const INSPECTOR_PANEL_POSITION (Vector2)
## O que: Posição do painel de inspeção de materiais no canto superior direito (800px, 20px).
## Porque: Painel auxiliar de diagnóstico visual.
const INSPECTOR_PANEL_POSITION: Vector2 = Vector2(800.0, 20.0)

## @const INSPECTOR_PANEL_SIZE (Vector2)
## O que: Dimensão do painel de inspeção (460px x 260px).
## Porque: Exibe listas de superfícies e status de texturas.
const INSPECTOR_PANEL_SIZE: Vector2 = Vector2(460.0, 260.0)

## @const BYTES_TO_MB (float)
## O que: Divisor para conversão de bytes para Megabytes (1024 * 1024 = 1048576.0).
## Porque: Exibição legível do consumo de RAM do engine.
const BYTES_TO_MB: float = 1048576.0

# ==============================================================================
# PROPRIEDADES DE UI
# ==============================================================================

signal actor_selected(actor_dict: Dictionary)
signal actor_transform_applied(actor_name: String, pos: Vector3, rot_deg: Vector3, scale: Vector3, chunk_name: String)
signal actor_fix_saved(actor_name: String, pos: Vector3, rot_deg: Vector3, scale: Vector3, chunk_name: String)
signal actor_reset_requested(actor_name: String, chunk_name: String)
signal actor_collision_changed(actor_name: String, new_type: String, chunk_name: String, package_name: String, mesh_name: String)
signal actor_collision_save_requested(package_name: String, mesh_name: String, collision_type: String)
signal batch_save_requested()
signal batch_discard_requested()

var _panel: PanelContainer
var _label_info: Label
var _inspector_panel: PanelContainer
var _label_inspector: Label

# Componentes do Inspetor de Atores no Raio (F4)
var _actor_panel: PanelContainer
var _label_actor_title: Label
var _label_pending_summary: Label
var _btn_batch_save: Button
var _btn_batch_discard: Button
var _dirty_actors_set: Dictionary = { }
var _search_input: LineEdit
var _item_list: ItemList
var _active_filter: String = "all"
var _search_text: String = ""
var _current_radius: float = 40.0
var _raw_nearby_actors: Array[Dictionary] = []
var _filtered_actors: Array[Dictionary] = []
var _selected_actor_name: String = ""
var _selected_actor_chunk: String = ""
var _selected_package_name: String = ""
var _selected_mesh_name: String = ""

# Componentes do Editor de Ator
var _editor_box: VBoxContainer
var _label_editor_title: Label
var _label_package_info: Label
var _option_collision_type: OptionButton
var _btn_save_collision: Button
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


func _ready() -> void:
	_setup_ui()


func _setup_ui() -> void:
	# Painel de Telemetria Geral (Esquerda)
	_panel = PanelContainer.new()
	_panel.position = PANEL_POSITION
	_panel.size = PANEL_SIZE
	add_child(_panel)

	_label_info = Label.new()
	_label_info.text = "Godotage II — Telemetria de Depuração\nFPS: --\nPos: (0.0, 0.0, 0.0)\nChunk: --\nWireframe: F2"
	_panel.add_child(_label_info)

	# Painel do Inspetor de Objetos e Materiais pelo Mouse (Direita)
	_inspector_panel = PanelContainer.new()
	_inspector_panel.anchor_left = 1.0
	_inspector_panel.anchor_right = 1.0
	_inspector_panel.position = INSPECTOR_PANEL_POSITION
	_inspector_panel.size = INSPECTOR_PANEL_SIZE
	_inspector_panel.visible = false
	add_child(_inspector_panel)

	_label_inspector = Label.new()
	_label_inspector.text = "Inspetor de Objetos (Mouse)"
	_inspector_panel.add_child(_label_inspector)

	_setup_actor_inspector_ui()


func _setup_actor_inspector_ui() -> void:
	_actor_panel = PanelContainer.new()
	_actor_panel.name = "ActorInspectorPanel"
	_actor_panel.anchor_left = 1.0
	_actor_panel.anchor_right = 1.0
	_actor_panel.anchor_top = 0.0
	_actor_panel.anchor_bottom = 1.0
	_actor_panel.offset_left = -480.0
	_actor_panel.offset_top = 20.0
	_actor_panel.offset_right = -20.0
	_actor_panel.offset_bottom = -20.0
	_actor_panel.visible = false
	add_child(_actor_panel)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_actor_panel.add_child(vbox)

	# Cabeçalho
	_label_actor_title = Label.new()
	_label_actor_title.text = "INSPETOR DE ATORES (Raio: 40m | 0 encontrados)\n[Ctrl + Scroll] Ajustar Raio"
	vbox.add_child(_label_actor_title)

	# Barra de Busca Textual
	_search_input = LineEdit.new()
	_search_input.placeholder_text = "Buscar ator, modelo ou pacote..."
	_search_input.text_changed.connect(_on_search_text_changed)
	vbox.add_child(_search_input)

	# Botões de Filtro por Categoria
	var hbox_filters = HBoxContainer.new()
	vbox.add_child(hbox_filters)

	var btn_all = Button.new()
	btn_all.text = "Todos"
	btn_all.pressed.connect(func(): _set_active_filter("all"))
	hbox_filters.add_child(btn_all)

	var btn_trees = Button.new()
	btn_trees.text = "Árvores"
	btn_trees.pressed.connect(func(): _set_active_filter("trees"))
	hbox_filters.add_child(btn_trees)

	var btn_bldg = Button.new()
	btn_bldg.text = "Construções"
	btn_bldg.pressed.connect(func(): _set_active_filter("bldg"))
	hbox_filters.add_child(btn_bldg)

	var btn_props = Button.new()
	btn_props.text = "Props"
	btn_props.pressed.connect(func(): _set_active_filter("props"))
	hbox_filters.add_child(btn_props)

	var btn_veg = Button.new()
	btn_veg.text = "Vegetação"
	btn_veg.pressed.connect(func(): _set_active_filter("veg"))
	hbox_filters.add_child(btn_veg)

	# Lista Rolável de Atores (com scroll automático)
	_item_list = ItemList.new()
	_item_list.custom_minimum_size = Vector2(0.0, 110.0)
	_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_list.item_selected.connect(_on_actor_item_selected)
	vbox.add_child(_item_list)

	# Seção Inferior: Editor de Propriedades do Ator (Ancorado em baixo)
	_setup_actor_editor_ui(vbox)


func _setup_actor_editor_ui(parent: Control) -> void:
	_editor_box = VBoxContainer.new()
	_editor_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor_box.size_flags_vertical = Control.SIZE_SHRINK_END
	_editor_box.visible = false
	parent.add_child(_editor_box)

	_label_editor_title = Label.new()
	_label_editor_title.text = "--- Propriedades do Ator ---"
	_editor_box.add_child(_label_editor_title)

	_label_package_info = Label.new()
	_label_package_info.text = "Pacote: -- | Chave: --"
	_label_package_info.modulate = Color(0.6, 0.9, 1.0)
	_editor_box.add_child(_label_package_info)

	# 1. Posição (Step de 10m para mudanças rápidas)
	var lbl_pos = Label.new()
	lbl_pos.text = "Posição (X, Y, Z):"
	_editor_box.add_child(lbl_pos)

	var hbox_pos = HBoxContainer.new()
	_editor_box.add_child(hbox_pos)
	_spin_pos_x = _create_spinbox(-100000.0, 100000.0, 0.001, 10.0, "X: ", " m")
	_spin_pos_y = _create_spinbox(-100000.0, 100000.0, 0.001, 10.0, "Y: ", " m")
	_spin_pos_z = _create_spinbox(-100000.0, 100000.0, 0.001, 10.0, "Z: ", " m")
	hbox_pos.add_child(_spin_pos_x)
	hbox_pos.add_child(_spin_pos_y)
	hbox_pos.add_child(_spin_pos_z)

	# 2. Rotação (Step decimal fino 0.001 com salto de seta de 15°)
	var lbl_rot = Label.new()
	lbl_rot.text = "Rotação (Pitch, Yaw, Roll):"
	_editor_box.add_child(lbl_rot)

	var hbox_rot = HBoxContainer.new()
	_editor_box.add_child(hbox_rot)
	_spin_rot_x = _create_spinbox(-360.0, 360.0, 0.001, 15.0, "P: ", "°")
	_spin_rot_y = _create_spinbox(-360.0, 360.0, 0.001, 15.0, "Y: ", "°")
	_spin_rot_z = _create_spinbox(-360.0, 360.0, 0.001, 15.0, "R: ", "°")
	hbox_rot.add_child(_spin_rot_x)
	hbox_rot.add_child(_spin_rot_y)
	hbox_rot.add_child(_spin_rot_z)

	# 3. Escala (Step decimal fino 0.001 com salto de seta de 0.25)
	var lbl_scale = Label.new()
	lbl_scale.text = "Escala (X, Y, Z):"
	_editor_box.add_child(lbl_scale)

	var hbox_scale = HBoxContainer.new()
	_editor_box.add_child(hbox_scale)
	_spin_scale_x = _create_spinbox(-100.0, 100.0, 0.001, 0.25, "X: ", "")
	_spin_scale_y = _create_spinbox(-100.0, 100.0, 0.001, 0.25, "Y: ", "")
	_spin_scale_z = _create_spinbox(-100.0, 100.0, 0.001, 0.25, "Z: ", "")
	_spin_scale_x.value = 1.0
	_spin_scale_y.value = 1.0
	_spin_scale_z.value = 1.0
	hbox_scale.add_child(_spin_scale_x)
	hbox_scale.add_child(_spin_scale_y)
	hbox_scale.add_child(_spin_scale_z)

	# 4. Colisão Física em Tempo Real e Persistência de Regras
	var lbl_col = Label.new()
	lbl_col.text = "Colisão Física (Regra Global):"
	_editor_box.add_child(lbl_col)

	var hbox_col = HBoxContainer.new()
	_editor_box.add_child(hbox_col)

	_option_collision_type = OptionButton.new()
	_option_collision_type.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_option_collision_type.add_item("🏛️ CONCAVE (Oco/Arquitetura)", 0)
	_option_collision_type.add_item("🪨 CONVEX (Sólido/Props)", 1)
	_option_collision_type.add_item("🌲 TREE_TRUNK (Tronco)", 2)
	_option_collision_type.add_item("🌿 PASS_THROUGH (Sem Colisão)", 3)
	_option_collision_type.item_selected.connect(_on_collision_option_selected)
	hbox_col.add_child(_option_collision_type)

	_btn_save_collision = Button.new()
	_btn_save_collision.text = "🛡️ Salvar Colisão"
	_btn_save_collision.pressed.connect(_on_btn_save_collision_pressed)
	hbox_col.add_child(_btn_save_collision)

	# 5. Botões de Ação de Transform Individual
	var hbox_actions = HBoxContainer.new()
	_editor_box.add_child(hbox_actions)

	var btn_reset = Button.new()
	btn_reset.text = "🔄 Resetar Ator"
	btn_reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_reset.pressed.connect(_on_btn_reset_pressed)
	hbox_actions.add_child(btn_reset)

	var btn_save = Button.new()
	btn_save.text = "💾 Salvar Fix"
	btn_save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_save.pressed.connect(_on_btn_save_pressed)
	hbox_actions.add_child(btn_save)

	# 6. Painel e Botões de Ação em Lote (Batch Commit)
	_label_pending_summary = Label.new()
	_label_pending_summary.text = "📦 Pendências: 0 ator(es) em 0 chunk(s)"
	_label_pending_summary.modulate = Color(0.7, 0.8, 0.9)
	_editor_box.add_child(_label_pending_summary)

	var hbox_batch = HBoxContainer.new()
	_editor_box.add_child(hbox_batch)

	_btn_batch_discard = Button.new()
	_btn_batch_discard.text = "🔄 Descartar Tudo"
	_btn_batch_discard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_batch_discard.pressed.connect(_on_btn_batch_discard_pressed)
	hbox_batch.add_child(_btn_batch_discard)

	_btn_batch_save = Button.new()
	_btn_batch_save.text = "💾 Salvar Tudo (Lote)"
	_btn_batch_save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_batch_save.pressed.connect(_on_btn_batch_save_pressed)
	hbox_batch.add_child(_btn_batch_save)

	# 7. Label de Status
	_label_editor_status = Label.new()
	_label_editor_status.text = ""
	_editor_box.add_child(_label_editor_status)


func _create_spinbox(
	min_val: float,
	max_val: float,
	step_val: float,
	arrow_step_val: float,
	prefix_str: String,
	suffix_str: String
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


func _on_spinbox_value_changed(_val: float) -> void:
	if _is_populating_fields or _selected_actor_name.is_empty():
		return
	var pos = Vector3(_spin_pos_x.value, _spin_pos_y.value, _spin_pos_z.value)
	var rot = Vector3(_spin_rot_x.value, _spin_rot_y.value, _spin_rot_z.value)
	var sc = Vector3(_spin_scale_x.value, _spin_scale_y.value, _spin_scale_z.value)
	actor_transform_applied.emit(_selected_actor_name, pos, rot, sc, _selected_actor_chunk)
	if _label_editor_status:
		_label_editor_status.text = "⚡ Atualizado em tempo real!"
		_label_editor_status.modulate = Color(0.2, 0.9, 1.0)


func _on_btn_save_pressed() -> void:
	if _selected_actor_name.is_empty():
		return
	var pos = Vector3(_spin_pos_x.value, _spin_pos_y.value, _spin_pos_z.value)
	var rot = Vector3(_spin_rot_x.value, _spin_rot_y.value, _spin_rot_z.value)
	var sc = Vector3(_spin_scale_x.value, _spin_scale_y.value, _spin_scale_z.value)
	actor_fix_saved.emit(_selected_actor_name, pos, rot, sc, _selected_actor_chunk)
	if _label_editor_status:
		_label_editor_status.text = "💾 Fix salvo em chunk_static_actors_fix.json!"
		_label_editor_status.modulate = Color(0.2, 1.0, 0.4)


func _on_btn_reset_pressed() -> void:
	if _selected_actor_name.is_empty():
		return
	actor_reset_requested.emit(_selected_actor_name, _selected_actor_chunk)


func set_editor_values(
	pos: Variant,
	rot_deg: Variant,
	sc: Variant,
	status_msg: String = ""
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
		_label_editor_status.modulate = Color(1.0, 0.85, 0.2)


func _on_search_text_changed(new_text: String) -> void:
	_search_text = new_text.strip_edges().to_lower()
	_apply_filters_and_refresh_list()


func _set_active_filter(filter_name: String) -> void:
	_active_filter = filter_name
	_apply_filters_and_refresh_list()


func _on_actor_item_selected(index: int) -> void:
	if index >= 0 and index < _filtered_actors.size():
		var actor_data = _filtered_actors[index]
		_selected_actor_name = actor_data.get("actor_name", "")
		_selected_actor_chunk = actor_data.get("chunk_name", "")
		_selected_package_name = actor_data.get("package_name", "")
		_selected_mesh_name = actor_data.get("mesh_name", "")

		if _editor_box:
			_editor_box.visible = true
		if _label_editor_title:
			_label_editor_title.text = "--- Propriedades: %s [%s] (%s) ---" % [
				actor_data.get("actor_name", ""),
				_selected_actor_chunk,
				actor_data.get("mesh_name", ""),
			]

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

		var raw_pos = actor_data.get("raw_position")
		var raw_rot = actor_data.get("raw_rotation_degrees")
		var raw_scl = actor_data.get("raw_scale")

		var pos_arg = raw_pos if (raw_pos is Array and raw_pos.size() >= 3) else actor_data.get("position", Vector3.ZERO)
		var rot_arg = raw_rot if (raw_rot is Array and raw_rot.size() >= 3) else actor_data.get("rotation_degrees", Vector3.ZERO)
		var scl_arg = raw_scl if (raw_scl is Array and raw_scl.size() >= 3) else actor_data.get("scale", Vector3.ONE)

		set_editor_values(pos_arg, rot_arg, scl_arg, "Ator selecionado para edição.")
		actor_selected.emit(actor_data)


func _on_collision_option_selected(idx: int) -> void:
	if _selected_actor_name.is_empty() or not _option_collision_type:
		return
	var type_str = "convex"
	match idx:
		0: type_str = "concave"
		1: type_str = "convex"
		2: type_str = "tree_trunk"
		3: type_str = "pass_through"
	actor_collision_changed.emit(
		_selected_actor_name,
		type_str,
		_selected_actor_chunk,
		_selected_package_name,
		_selected_mesh_name,
	)
	if _label_editor_status:
		_label_editor_status.text = "⚡ Colisor alterado para %s!" % type_str.to_upper()
		_label_editor_status.modulate = Color(0.2, 0.9, 1.0)


func _on_btn_save_collision_pressed() -> void:
	if _selected_mesh_name.is_empty() or not _option_collision_type:
		return
	var type_str = "convex"
	match _option_collision_type.selected:
		0: type_str = "concave"
		1: type_str = "convex"
		2: type_str = "tree_trunk"
		3: type_str = "pass_through"
	actor_collision_save_requested.emit(
		_selected_package_name,
		_selected_mesh_name,
		type_str,
	)
	if _label_editor_status:
		_label_editor_status.text = "🛡️ Regra de colisão salva em static_mesh_collision_rules.json!"
		_label_editor_status.modulate = Color(0.2, 1.0, 0.4)


func toggle_actor_inspector() -> void:
	if _actor_panel:
		_actor_panel.visible = not _actor_panel.visible


func is_actor_inspector_open() -> bool:
	return _actor_panel != null and _actor_panel.visible


func get_selected_actor_name() -> String:
	return _selected_actor_name


func get_selected_actor_chunk() -> String:
	return _selected_actor_chunk


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


func clear_selection() -> void:
	_selected_actor_name = ""
	_selected_actor_chunk = ""
	_selected_package_name = ""
	_selected_mesh_name = ""
	if _editor_box:
		_editor_box.visible = false
	if _item_list:
		_item_list.deselect_all()


func update_nearby_actors(actors: Array[Dictionary], current_radius: float) -> void:
	_raw_nearby_actors = actors
	_current_radius = current_radius
	_apply_filters_and_refresh_list()


func _apply_filters_and_refresh_list() -> void:
	if not _actor_panel or not _item_list:
		return

	_filtered_actors.clear()
	_item_list.clear()

	for a in _raw_nearby_actors:
		var a_name = a.get("actor_name", "").to_lower()
		var m_name = a.get("mesh_name", "").to_lower()
		var pkg = a.get("package_name", "").to_lower()
		var c_type = a.get("classification_type", "convex")

		# Filtro de Categoria
		if _active_filter == "trees" and not (c_type in ["tree_trunk", "tree_trunk_surface"]):
			continue
		elif _active_filter == "bldg" and c_type != "concave":
			continue
		elif _active_filter == "props" and c_type != "convex":
			continue
		elif _active_filter == "veg" and c_type != "pass_through":
			continue

		# Filtro de Busca Textual
		if not _search_text.is_empty():
			if not (_search_text in a_name or _search_text in m_name or _search_text in pkg):
				continue

		_filtered_actors.append(a)

	if _label_actor_title:
		_label_actor_title.text = "INSPETOR DE ATORES (Raio: %.0fm | %d encontrados)\n[Alt + Scroll] Ajustar Raio" % [
			_current_radius,
			_filtered_actors.size(),
		]

	var selected_idx = -1
	for i in range(_filtered_actors.size()):
		var a = _filtered_actors[i]
		var dist = a.get("distance", 0.0)
		var c_type = a.get("classification_type", "convex").to_upper()
		var chunk_tag = "[%s]" % a.get("chunk_name", "") if not a.get("chunk_name", "").is_empty() else ""
		var is_dirty = _dirty_actors_set.has("%s:%s" % [a.get("chunk_name", ""), a.get("actor_name", "")]) or _dirty_actors_set.has(a.get("actor_name", ""))
		var dirty_prefix = "* " if is_dirty else ""
		var item_text = "%s[%.1fm] %s %s | %s [%s]" % [
			dirty_prefix,
			dist,
			a.get("actor_name", "Actor"),
			chunk_tag,
			a.get("mesh_name", "Mesh"),
			c_type,
		]
		_item_list.add_item(item_text)
		if is_dirty:
			_item_list.set_item_custom_fg_color(i, Color(1.0, 0.85, 0.2))
		if (
			not _selected_actor_name.is_empty()
			and a.get("actor_name", "") == _selected_actor_name
			and (
				_selected_actor_chunk.is_empty()
				or a.get("chunk_name", "") == _selected_actor_chunk
			)
		):
			selected_idx = i

	if selected_idx >= 0:
		_item_list.select(selected_idx)


func update_pending_summary(summary: Dictionary) -> void:
	var total = int(summary.get("total_actors", 0))
	var chunks_cnt = int(summary.get("chunks_count", 0))
	if _label_pending_summary:
		_label_pending_summary.text = "📦 Pendências: %d ator(es) em %d chunk(s)" % [total, chunks_cnt]
		if total > 0:
			_label_pending_summary.modulate = Color(1.0, 0.85, 0.2)
		else:
			_label_pending_summary.modulate = Color(0.7, 0.8, 0.9)


func set_dirty_actors(dirty_map: Dictionary) -> void:
	_dirty_actors_set = dirty_map
	_apply_filters_and_refresh_list()


func _on_btn_batch_save_pressed() -> void:
	batch_save_requested.emit()


func _on_btn_batch_discard_pressed() -> void:
	batch_discard_requested.emit()


func is_mouse_over_ui() -> bool:
	var vp = get_viewport()
	if not vp:
		return false
	var mouse_pos = vp.get_mouse_position()
	if _actor_panel and _actor_panel.visible and _actor_panel.get_global_rect().has_point(mouse_pos):
		return true
	if _panel and _panel.visible and _panel.get_global_rect().has_point(mouse_pos):
		return true
	if _inspector_panel and _inspector_panel.visible and _inspector_panel.get_global_rect().has_point(mouse_pos):
		return true
	return false


func update_telemetry(
	player_pos: Vector3,
	active_chunk: String,
	altitude_found: float = 0.0,
	wireframe_on: bool = false,
) -> void:
	if not _label_info:
		return

	var fps = Engine.get_frames_per_second()
	var mode_str = ""
	if wireframe_on:
		mode_str += " [WIREFRAME 60FPS]"

	_label_info.text = "Godotage II — Depuração 3D (Lineage II)%s\n" % mode_str + "FPS: %d | Mem: %.1f MB\n" % [
		fps,
		OS.get_static_memory_usage() / BYTES_TO_MB,
	] + "Pos: (%.1f, %.1f, %.1f)m\n" % [player_pos.x, player_pos.y, player_pos.z] + "Chunk Ativo: %s | Altura Solo: %.1fm\n" % [
		active_chunk if not active_chunk.is_empty() else "Nenhum",
		altitude_found,
	] + "-------------------------------------\n" + \
	"[F2] HUD\n" + \
	"[F3] Wireframe\n" + \
	"[F4] Atores\n" + \
	"[F5] Colisão\n" + \
	"[F10] Água\n" + \
	"[F12] Sombras"


func update_inspector_info(data: Dictionary) -> void:
	if not _inspector_panel or not _label_inspector:
		return

	if not data.get("found", false):
		_inspector_panel.visible = false
		return

	_inspector_panel.visible = true
	var p = data.get("position", Vector3.ZERO)
	var text = "🔍 [INSPETOR DE MATERIAIS / MOUSE]\n" + "Ator: %s\n" % data.get("actor_name", "--") + "Modelo: %s (Pacote: %s)\n" % [
		data.get("mesh_name", "--"),
		data.get("package_name", "--"),
	] + "Posição: (%.1f, %.1f, %.1f)m | Dist: %.1fm\n" % [p.x, p.y, p.z, data.get("distance", 0.0)] + "--------------------------------------------------\n" + "Superfícies & Texturas (%d):\n" % data \
			.get("surfaces", []) \
			.size()

	var surfs = data.get("surfaces", [])
	for s in surfs:
		var status_str = s.get("status", "MISSING")
		var icon = "✅" if "OK" in status_str else "❌"
		text += "%s [%d] %s\n    └─ %s (%s)\n" % [
			icon,
			s.get("index", 0),
			s.get("name", ""),
			status_str,
			s.get("texture_path", "N/A"),
		]

	_label_inspector.text = text


func toggle_visibility() -> void:
	visible = not visible
