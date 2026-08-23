## @file debug_world_editor.gd
## @path res://src/debug/debug_world_editor.gd
##
## @description
## Controlador e editor in-game de desenvolvimento (World Editor / Mini-IDE).
## Encapsula atalhos de teclado (F2..F12, ESC, Ctrl+S), manipulação 3D de atores,
## gizmos de seleção/raio, telemetria, teleportes e o staging buffer de persistência.
##
## @created 2026-08-22
## @updated 2026-08-22
##
## @author Leonardo S. Badaró
extends Node

const DebugHUDClass = preload("res://src/infrastructure/debug_hud.gd")
const RadiusGizmoNodeClass = preload("res://src/infrastructure/radius_gizmo_node.gd")
const MeshSelectionHighlighterClass = preload(
	"res://src/infrastructure/mesh_selection_highlighter.gd"
)
const ChunkResourceAdapterClass = preload("res://src/adapters/chunk_resource_adapter.gd")

# Constantes de Depuração
const INSPECTOR_UPDATE_INTERVAL_SEC: float = 0.25
const DRAG_RAY_LENGTH: float = 1000.0

var world_chunk_manager: Node3D
var local_player: CharacterBody3D
var directional_light: DirectionalLight3D

var _debug_hud: CanvasLayer
var _radius_gizmo: Node3D
var _mesh_selection_highlighter: Node3D
var _resource_adapter: RefCounted

var _wireframe_active: bool = false
var _inspector_radius: float = 40.0
var _inspector_timer: float = 0.0

var _selected_actor_name: String = ""
var _selected_actor_chunk: String = ""
var _drag_height_offset: float = 0.0
var _is_dragging_actor: bool = false
var _current_chunk_name: String = ""


func setup(
	p_chunk_mgr: Node3D,
	p_player: CharacterBody3D,
	p_dir_light: DirectionalLight3D = null,
) -> void:
	world_chunk_manager = p_chunk_mgr
	local_player = p_player
	directional_light = p_dir_light
	_resource_adapter = ChunkResourceAdapterClass.new("res://assets/maps")

	# 1. Instancia HUD da Mini-IDE
	_debug_hud = DebugHUDClass.new()
	_debug_hud.name = "DebugHUD"
	_debug_hud.actor_selected.connect(_on_actor_selected_in_hud)
	_debug_hud.actor_transform_applied.connect(_on_actor_transform_applied)
	_debug_hud.actor_fix_saved.connect(_on_actor_fix_saved)
	_debug_hud.actor_reset_requested.connect(_on_actor_reset_requested)
	_debug_hud.actor_collision_changed.connect(_on_actor_collision_changed)
	_debug_hud.actor_collision_save_requested.connect(_on_actor_collision_save_requested)
	_debug_hud.batch_save_requested.connect(_on_batch_save_requested)
	_debug_hud.batch_discard_requested.connect(_on_batch_discard_requested)

	# Sinais de Menu e Ferramentas da Top Bar
	_debug_hud.teleport_requested.connect(_on_teleport_requested)
	_debug_hud.bookmark_save_requested.connect(_on_bookmark_save_requested)
	_debug_hud.radius_changed.connect(_on_radius_changed)
	_debug_hud.toggle_wireframe_requested.connect(_toggle_wireframe)
	_debug_hud.toggle_collisions_requested.connect(_toggle_debug_collisions)
	_debug_hud.toggle_shadows_requested.connect(_toggle_shadows)
	_debug_hud.water_volume_transform_applied.connect(_on_water_volume_transform_applied)
	_debug_hud.water_volume_fix_saved.connect(_on_water_volume_fix_saved)
	_debug_hud.water_volume_reset_requested.connect(_on_water_volume_reset_requested)
	_debug_hud.water_volumes_refresh_requested.connect(_on_water_volumes_refresh_requested)

	# Sinais do Injetor de Hacks (Test Harness)
	_debug_hud.speedhack_toggled.connect(_on_speedhack_toggled)
	_debug_hud.force_teleport_requested.connect(_on_force_teleport_requested)
	_debug_hud.noclip_toggled.connect(_on_noclip_toggled)
	_debug_hud.flyhack_requested.connect(_on_flyhack_requested)

	add_child(_debug_hud)

	# Conexão com Snapbacks do QuanticNet
	if is_inside_tree():
		var qn = get_node_or_null("/root/QuanticNet")
		if qn and qn.has_signal("snapback_received"):
			if not qn.snapback_received.is_connected(_on_snapback_received):
				qn.snapback_received.connect(_on_snapback_received)

	if local_player:
		local_player.is_ui_hovered_callback = _debug_hud.is_mouse_over_ui

	# 2. Carrega lista inicial de teleportes
	if _resource_adapter and _debug_hud.has_method("load_teleports"):
		_debug_hud.load_teleports(_resource_adapter.load_world_teleports())

	# 3. Instancia Gizmo de Raio 3D e Highlighter de Seleção
	_radius_gizmo = RadiusGizmoNodeClass.new(_inspector_radius)
	_radius_gizmo.name = "RadiusGizmoNode"
	_radius_gizmo.visible = false
	add_child(_radius_gizmo)

	_mesh_selection_highlighter = MeshSelectionHighlighterClass.new()
	_mesh_selection_highlighter.name = "MeshSelectionHighlighter"
	add_child(_mesh_selection_highlighter)


func _physics_process(delta: float) -> void:
	if not local_player or not _debug_hud or not world_chunk_manager:
		return

	# Atualiza telemetria no HUD
	var alt_res = world_chunk_manager.sample_world_altitude(
		local_player.position.x,
		local_player.position.z,
	)
	var active_chunk = alt_res.get("chunk_name", "")
	var alt_val = alt_res.get("altitude", 0.0)
	var is_flying = local_player.get("is_flying") if "is_flying" in local_player else false
	var stream_stats = world_chunk_manager.get_streaming_stats() if world_chunk_manager.has_method(
		"get_streaming_stats"
	) else { }

	var net_stats = { }
	if is_inside_tree():
		var qn = get_node_or_null("/root/QuanticNet")
		if qn:
			var st_str = qn.get_state_string() if qn.has_method("get_state_string") else "Desconhecido"
			var t_dict = qn.get_telemetry_dict() if qn.has_method("get_telemetry_dict") else { }
			var my_id = qn.get_local_peer_id() if qn.has_method("get_local_peer_id") else 0
			net_stats = {
				"status": "%s (Peer ID: %d)" % [st_str, my_id],
				"ping_ms": t_dict.get("rtt_ms", 0.0),
				"avg_ping_ms": t_dict.get("avg_rtt_ms", 0.0),
				"loss_pct": t_dict.get("loss_pct", 0.0),
			}

	_debug_hud.update_telemetry(
		local_player.position,
		active_chunk,
		_wireframe_active,
		alt_val,
		is_flying,
		stream_stats,
		net_stats,
	)

	if not active_chunk.is_empty() and active_chunk != _current_chunk_name:
		_current_chunk_name = active_chunk
		var water_data = world_chunk_manager.get_chunk_water_volumes(_current_chunk_name)
		_debug_hud.populate_water_volumes(_current_chunk_name, water_data)

	# Atualiza Gizmo e Inspetor
	var is_open = _debug_hud.is_actor_inspector_open() if _debug_hud else false
	if _radius_gizmo:
		_radius_gizmo.visible = is_open
		if is_open:
			_radius_gizmo.position = local_player.position

	if is_open:
		_inspector_timer += delta
		if _inspector_timer >= INSPECTOR_UPDATE_INTERVAL_SEC:
			_inspector_timer = 0.0
			var nearby = world_chunk_manager.get_static_actors_in_radius(
				local_player.position,
				_inspector_radius,
			)
			_debug_hud.update_nearby_actors(nearby, _inspector_radius)
			_refresh_pending_hud_summary()


func _unhandled_input(event: InputEvent) -> void:
	# 1. Teclas de Atalho (Teclado)
	if event is InputEventKey and event.pressed and not event.echo:
		# Tecla ESC: Fechamento em Cascata das Janelas Abertas
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
			if _debug_hud and _debug_hud.close_topmost_window():
				_selected_actor_name = ""
				_selected_actor_chunk = ""
				if _mesh_selection_highlighter:
					_mesh_selection_highlighter.clear_highlight()
				get_viewport().set_input_as_handled()
				return

		# Tecla F2: Alterna Visibilidade da Janela de Telemetria
		elif event.keycode == KEY_F2 or event.physical_keycode == KEY_F2:
			if _debug_hud and _debug_hud.has_method("toggle_telemetry_window"):
				_debug_hud.toggle_telemetry_window()
				get_viewport().set_input_as_handled()
				return

		# Tecla F3: Alterna Wireframe
		elif event.keycode == KEY_F3 or event.physical_keycode == KEY_F3:
			_toggle_wireframe()
			get_viewport().set_input_as_handled()
			return

		# Tecla F4: Alterna Painel do World Outliner
		elif event.keycode == KEY_F4 or event.physical_keycode == KEY_F4:
			if _debug_hud:
				_debug_hud.toggle_actor_inspector_visibility()
				var is_open = _debug_hud.is_actor_inspector_open()
				if _radius_gizmo:
					_radius_gizmo.visible = is_open
				if is_open and local_player and world_chunk_manager:
					var nearby = world_chunk_manager.get_static_actors_in_radius(
						local_player.position,
						_inspector_radius,
					)
					_debug_hud.update_nearby_actors(nearby, _inspector_radius)
					_refresh_pending_hud_summary()
			get_viewport().set_input_as_handled()
			return

	# 2. Cliques do Mouse e Manipulação 3D no Viewport
	if event is InputEventMouseButton:
		# Botão Esquerdo Solto: Finaliza o estado de arrasto de ator
		if not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging_actor = false

		# Rotação Rápida de Ator com Shift + Scroll (Yaw +/- 15.0°)
		elif event.pressed and event.shift_pressed:
			if not _selected_actor_name.is_empty() and _debug_hud and world_chunk_manager:
				var cur_pos = _debug_hud.get_current_position()
				var cur_rot = _debug_hud.get_current_rotation()
				var cur_sc = _debug_hud.get_current_scale()

				if event.button_index == MOUSE_BUTTON_WHEEL_UP:
					cur_rot.y = fmod(cur_rot.y + 15.0, 360.0)
					_on_actor_transform_applied(
						_selected_actor_name,
						cur_pos,
						cur_rot,
						cur_sc,
						_selected_actor_chunk,
					)
					_debug_hud.set_editor_values(
						cur_pos,
						cur_rot,
						cur_sc,
						"Rotacao aplicada (+15°)",
					)
					get_viewport().set_input_as_handled()
					return
				elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					cur_rot.y = fmod(cur_rot.y - 15.0, 360.0)
					_on_actor_transform_applied(
						_selected_actor_name,
						cur_pos,
						cur_rot,
						cur_sc,
						_selected_actor_chunk,
					)
					_debug_hud.set_editor_values(
						cur_pos,
						cur_rot,
						cur_sc,
						"Rotacao aplicada (-15°)",
					)
					get_viewport().set_input_as_handled()
					return

		# Controle Fino de Elevação Vertical (Y) com Ctrl + Scroll (+/- 0.10m suave)
		elif event.pressed and event.ctrl_pressed:
			if not _selected_actor_name.is_empty() and _debug_hud and world_chunk_manager:
				var cur_pos = _debug_hud.get_current_position()
				var cur_rot = _debug_hud.get_current_rotation()
				var cur_sc = _debug_hud.get_current_scale()
				var step_y = 0.10

				if event.button_index == MOUSE_BUTTON_WHEEL_UP:
					cur_pos.y = round((cur_pos.y + step_y) * 1000.0) / 1000.0
					_on_actor_transform_applied(
						_selected_actor_name,
						cur_pos,
						cur_rot,
						cur_sc,
						_selected_actor_chunk,
					)
					_debug_hud.set_editor_values(
						cur_pos,
						cur_rot,
						cur_sc,
						"Elevacao ajustada (+0.10m)",
					)
					get_viewport().set_input_as_handled()
					return
				elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					cur_pos.y = round((cur_pos.y - step_y) * 1000.0) / 1000.0
					_on_actor_transform_applied(
						_selected_actor_name,
						cur_pos,
						cur_rot,
						cur_sc,
						_selected_actor_chunk,
					)
					_debug_hud.set_editor_values(
						cur_pos,
						cur_rot,
						cur_sc,
						"Elevacao ajustada (-0.10m)",
					)
					get_viewport().set_input_as_handled()
					return

		# Ajuste Dinâmico do Raio de Inspeção com Alt + Scroll
		elif event.pressed and event.alt_pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_inspector_radius = clampf(_inspector_radius + 5.0, 5.0, 100.0)
				if _radius_gizmo:
					_radius_gizmo.set_radius(_inspector_radius)
				if (
					_debug_hud and _debug_hud.is_actor_inspector_open()
					and local_player and world_chunk_manager
				):
					var nearby = world_chunk_manager.get_static_actors_in_radius(
						local_player.position,
						_inspector_radius,
					)
					_debug_hud.update_nearby_actors(nearby, _inspector_radius)
				get_viewport().set_input_as_handled()
				return
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_inspector_radius = clampf(_inspector_radius - 5.0, 5.0, 100.0)
				if _radius_gizmo:
					_radius_gizmo.set_radius(_inspector_radius)
				if (
					_debug_hud and _debug_hud.is_actor_inspector_open()
					and local_player and world_chunk_manager
				):
					var nearby = world_chunk_manager.get_static_actors_in_radius(
						local_player.position,
						_inspector_radius,
					)
					_debug_hud.update_nearby_actors(nearby, _inspector_radius)
				get_viewport().set_input_as_handled()
				return

	# 3. Arrasto Livre de Ator no Relevo com Shift + Botão Esquerdo do Mouse Pressionado
	if (
		event is InputEventMouseMotion and event.shift_pressed
		and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	):
		if not _selected_actor_name.is_empty() and _debug_hud and world_chunk_manager:
			var camera = get_viewport().get_camera_3d()
			if not camera:
				return

			var mouse_pos = event.position
			var ray_origin = camera.project_ray_origin(mouse_pos)
			var ray_dir = camera.project_ray_normal(mouse_pos)

			var d_cam_actor = camera.global_position.distance_to(_debug_hud.get_current_position())
			d_cam_actor = clampf(d_cam_actor, 2.0, 500.0)
			var approx_point = ray_origin + ray_dir * d_cam_actor

			var target_x = approx_point.x
			var target_z = approx_point.z

			var alt_res = world_chunk_manager.sample_world_altitude(target_x, target_z)
			if alt_res.get("found", false):
				var ground_y = alt_res.get("altitude", 0.0)
				var cur_pos = _debug_hud.get_current_position()

				if not _is_dragging_actor:
					_is_dragging_actor = true
					var initial_ground_res = world_chunk_manager.sample_world_altitude(
						cur_pos.x,
						cur_pos.z,
					)
					var initial_ground_y = initial_ground_res.get("altitude", cur_pos.y) if initial_ground_res.get(
						"found",
						false,
					) else cur_pos.y
					_drag_height_offset = cur_pos.y - initial_ground_y

				var target_y = ground_y + _drag_height_offset
				var new_pos = Vector3(
					round(target_x * 1000.0) / 1000.0,
					round(target_y * 1000.0) / 1000.0,
					round(target_z * 1000.0) / 1000.0,
				)
				var cur_rot = _debug_hud.get_current_rotation()
				var cur_sc = _debug_hud.get_current_scale()

				_on_actor_transform_applied(
					_selected_actor_name,
					new_pos,
					cur_rot,
					cur_sc,
					_selected_actor_chunk,
				)
				_debug_hud.set_editor_values(
					new_pos,
					cur_rot,
					cur_sc,
					"Arrastando ator (ancorado ao solo)...",
				)

# ==============================================================================
# MANIPULAÇÃO DE ATORES E CALLBACKS DO HUD
# ==============================================================================


func _on_actor_selected_in_hud(actor_dict: Dictionary) -> void:
	_selected_actor_name = actor_dict.get("actor_name", "")
	_selected_actor_chunk = actor_dict.get("chunk_name", "")
	if not _mesh_selection_highlighter:
		return

	if _selected_actor_name.is_empty():
		_mesh_selection_highlighter.clear_highlight()
		return

	var mesh = actor_dict.get("mesh", null)
	var xform = actor_dict.get("transform", Transform3D.IDENTITY)
	var aabb = actor_dict.get("aabb", AABB())

	if mesh:
		_mesh_selection_highlighter.highlight_mesh_and_aabb(mesh, xform, aabb)
	else:
		_mesh_selection_highlighter.highlight_aabb(aabb)


func _on_actor_transform_applied(
	actor_name: String,
	pos: Vector3,
	rot_deg: Vector3,
	sc: Vector3,
	chunk_name: String = "",
) -> void:
	if not world_chunk_manager:
		return
	var target_chunk = chunk_name if not chunk_name.is_empty() else _selected_actor_chunk
	var res = world_chunk_manager.update_static_actor_transform(
		actor_name,
		pos,
		rot_deg,
		sc,
		target_chunk,
	)
	if res.get("found", false) and _mesh_selection_highlighter:
		var mesh = res.get("mesh", null)
		var xform = res.get("transform", Transform3D.IDENTITY)
		var aabb = res.get("aabb", AABB())
		if mesh:
			_mesh_selection_highlighter.highlight_mesh_and_aabb(mesh, xform, aabb)
		else:
			_mesh_selection_highlighter.highlight_aabb(aabb)
		_refresh_pending_hud_summary()


func _on_actor_fix_saved(
	actor_name: String,
	pos: Vector3,
	rot_deg: Vector3,
	sc: Vector3,
	chunk_name: String = "",
) -> void:
	if not world_chunk_manager:
		return
	var target_chunk = chunk_name if not chunk_name.is_empty() else _selected_actor_chunk
	_on_actor_transform_applied(actor_name, pos, rot_deg, sc, target_chunk)
	var success = world_chunk_manager.save_actor_fix(actor_name, pos, rot_deg, sc, target_chunk)
	if success:
		_refresh_pending_hud_summary()
		print(
			"[DEBUG] chunk_static_actors_fix.json salvo com sucesso para ator '%s' [%s]."
			% [actor_name, target_chunk]
		)
	else:
		print(
			"[DEBUG] Falha ao salvar chunk_static_actors_fix.json para ator '%s' [%s]."
			% [actor_name, target_chunk]
		)


func _on_actor_reset_requested(actor_name: String, chunk_name: String = "") -> void:
	if not world_chunk_manager:
		return
	var target_chunk = chunk_name if not chunk_name.is_empty() else _selected_actor_chunk
	var raw = world_chunk_manager.get_raw_actor_data(actor_name, target_chunk)
	if not raw.is_empty():
		var pos = raw.get("position", Vector3.ZERO)
		var rot = raw.get("rotation_degrees", Vector3.ZERO)
		var sc = raw.get("scale", Vector3.ONE)
		_on_actor_transform_applied(actor_name, pos, rot, sc, target_chunk)
		if world_chunk_manager.has_method("remove_from_pending_fixes"):
			world_chunk_manager.remove_from_pending_fixes(actor_name, target_chunk)
		_refresh_pending_hud_summary()
		if _debug_hud:
			var raw_pos = raw.get("raw_position", pos)
			var raw_rot = raw.get("raw_rotation_degrees", rot)
			var raw_sc = raw.get("raw_scale", sc)
			_debug_hud.set_editor_values(
				raw_pos,
				raw_rot,
				raw_sc,
				"Valores restaurados para o original!",
			)
		print(
			"[DEBUG] Ator '%s' [%s] resetado para valores originais." % [actor_name, target_chunk]
		)


func _refresh_pending_hud_summary() -> void:
	if not _debug_hud or not world_chunk_manager:
		return
	if world_chunk_manager.has_method("get_pending_fixes_summary"):
		var summary = world_chunk_manager.get_pending_fixes_summary()
		_debug_hud.update_pending_summary(summary)


func _on_batch_save_requested() -> void:
	if not world_chunk_manager:
		return
	var res = world_chunk_manager.save_all_pending_actor_fixes()
	var count = res.get("saved_actors_count", 0)
	var chunks = res.get("saved_chunks", [])
	var msg = "Lote salvo: %d atores persistidos nos chunks %s!" % [count, str(chunks)]
	print("[DEBUG] %s" % msg)
	_refresh_pending_hud_summary()
	if _debug_hud:
		var cur_pos = _debug_hud.get_current_position()
		var cur_rot = _debug_hud.get_current_rotation()
		var cur_sc = _debug_hud.get_current_scale()
		_debug_hud.set_editor_values(cur_pos, cur_rot, cur_sc, msg)
		if _debug_hud.is_actor_inspector_open() and local_player:
			var nearby = world_chunk_manager.get_static_actors_in_radius(
				local_player.position,
				_inspector_radius,
			)
			_debug_hud.update_nearby_actors(nearby, _inspector_radius)


func _on_batch_discard_requested() -> void:
	if not world_chunk_manager:
		return
	var count = world_chunk_manager.discard_all_pending_actor_fixes()
	var msg = "Lote descartado: %d atores revertidos para original!" % count
	print("[DEBUG] %s" % msg)
	_refresh_pending_hud_summary()
	if _debug_hud:
		if not _selected_actor_name.is_empty():
			var raw = world_chunk_manager.get_raw_actor_data(
				_selected_actor_name,
				_selected_actor_chunk,
			)
			if not raw.is_empty():
				_debug_hud.set_editor_values(
					raw.get("position", Vector3.ZERO),
					raw.get("rotation_degrees", Vector3.ZERO),
					raw.get("scale", Vector3.ONE),
					msg,
				)
		if _debug_hud.is_actor_inspector_open() and local_player:
			var nearby = world_chunk_manager.get_static_actors_in_radius(
				local_player.position,
				_inspector_radius,
			)
			_debug_hud.update_nearby_actors(nearby, _inspector_radius)


func _on_actor_collision_changed(
	actor_name: String,
	new_type: String,
	chunk_name: String,
	_package_name: String,
	_mesh_name: String,
) -> void:
	if not world_chunk_manager:
		return
	var target_chunk = chunk_name if not chunk_name.is_empty() else _selected_actor_chunk
	var success = world_chunk_manager.update_actor_collision_type(
		actor_name,
		new_type,
		target_chunk,
	)
	if success:
		print(
			"[DEBUG] Colisor do ator '%s' [%s] alterado dinamicamente para %s."
			% [actor_name, target_chunk, new_type.to_upper()]
		)
		var tree = get_tree()
		if tree and tree.debug_collisions_hint:
			_refresh_collision_shapes_recursive(tree.root)


func _on_actor_collision_save_requested(
	package_name: String,
	mesh_name: String,
	collision_type: String,
) -> void:
	if not world_chunk_manager:
		return
	var success = world_chunk_manager.save_collision_rule_override(
		package_name,
		mesh_name,
		collision_type,
	)
	if success:
		print(
			"[DEBUG] Regra de colisão salva com sucesso em static_mesh_collision_rules.json para '%s.%s' -> %s."
			% [package_name, mesh_name, collision_type]
		)
	else:
		print("[DEBUG] Falha ao salvar regra de colisão para '%s.%s'." % [package_name, mesh_name])

# ==============================================================================
# TELEPORTES E CONTROLES DA TOP BAR
# ==============================================================================


func _on_teleport_requested(target_pos: Vector3) -> void:
	if not local_player:
		return
	local_player.position = target_pos
	local_player.velocity = Vector3.ZERO
	if world_chunk_manager:
		world_chunk_manager.update_streaming(target_pos, false)
	print(
		"[DEBUG] Teleporte executado para: (%.1f, %.1f, %.1f)"
		% [target_pos.x, target_pos.y, target_pos.z]
	)


func _on_bookmark_save_requested(b_name: String, b_pos: Vector3, b_chunk: String) -> void:
	if not _resource_adapter:
		return
	var success = _resource_adapter.save_world_teleport(b_name, b_pos, b_chunk)
	if success:
		_debug_hud.load_teleports(_resource_adapter.load_world_teleports())
		print("[DEBUG] Bookmark '%s' salvo com sucesso em world_teleports.json." % b_name)


func _on_radius_changed(new_r: float) -> void:
	_inspector_radius = new_r
	if _radius_gizmo:
		_radius_gizmo.set_radius(new_r)
	if world_chunk_manager and local_player:
		var nearby = world_chunk_manager.get_static_actors_in_radius(
			local_player.position,
			_inspector_radius,
		)
		if _debug_hud:
			_debug_hud.update_nearby_actors(nearby, _inspector_radius)


func _toggle_wireframe() -> void:
	_wireframe_active = not _wireframe_active
	if world_chunk_manager:
		world_chunk_manager.set_wireframe_enabled(_wireframe_active)
	print("[DEBUG] Modo Wireframe: ", "ATIVADO" if _wireframe_active else "DESATIVADO")


func _toggle_debug_collisions() -> void:
	var tree = get_tree()
	if not tree:
		return
	tree.debug_collisions_hint = not tree.debug_collisions_hint
	_refresh_collision_shapes_recursive(tree.root)
	print(
		"[DEBUG] Visualização de Colisores de Física: ",
		"LIGADA" if tree.debug_collisions_hint else "DESLIGADA",
	)


func _toggle_shadows() -> void:
	if directional_light:
		directional_light.shadow_enabled = not directional_light.shadow_enabled
		print(
			"[DEBUG] Sombras Direcionais: ",
			"ATIVADAS" if directional_light.shadow_enabled else "DESATIVADAS",
		)


func _refresh_collision_shapes_recursive(node: Node) -> void:
	if not node:
		return
	if node is CollisionShape3D:
		var col_shape: CollisionShape3D = node
		var s = col_shape.shape
		if s:
			col_shape.shape = null
			col_shape.shape = s
	for child in node.get_children():
		_refresh_collision_shapes_recursive(child)


func _on_water_volume_transform_applied(chunk_name: String, volume_name: String, data: Dictionary) -> void:
	if not world_chunk_manager:
		return
	world_chunk_manager.update_water_volume_runtime(chunk_name, volume_name, data)


func _on_water_volume_fix_saved(chunk_name: String, volume_name: String, data: Dictionary) -> void:
	if not world_chunk_manager:
		return
	var success = world_chunk_manager.save_single_water_volume_fix(chunk_name, volume_name, data)
	if success:
		print(
			"[DEBUG] water_volumes_fix.json salvo com sucesso para chunk '%s' (volume: %s)."
			% [chunk_name, volume_name]
		)


func _on_water_volume_reset_requested(chunk_name: String, volume_name: String) -> void:
	if not world_chunk_manager:
		return
	var raw_data = world_chunk_manager.reset_water_volume(chunk_name, volume_name)
	if _debug_hud and not raw_data.is_empty():
		var all_vols = world_chunk_manager.get_chunk_water_volumes(chunk_name)
		_debug_hud.populate_water_volumes(chunk_name, all_vols)
	print(
		"[DEBUG] Volume de agua '%s' [%s] resetado para os valores originais."
		% [volume_name, chunk_name]
	)


func _on_water_volumes_refresh_requested(chunk_name: String) -> void:
	if not world_chunk_manager or not _debug_hud:
		return
	var target_chunk = chunk_name if not chunk_name.is_empty() else _current_chunk_name
	var water_data = world_chunk_manager.get_chunk_water_volumes(target_chunk)
	_debug_hud.populate_water_volumes(target_chunk, water_data)


func _on_speedhack_toggled(active: bool) -> void:
	if local_player and local_player.has_method("set_speedhack"):
		local_player.set_speedhack(active, 5.0)
		print("[HACK TEST] Speedhack 5x: ", "ATIVADO" if active else "DESATIVADO")


func _on_force_teleport_requested(forward_dist: float) -> void:
	if local_player and local_player.has_method("apply_forced_teleport"):
		local_player.apply_forced_teleport(forward_dist)
		print("[HACK TEST] Teleporte Forçado disparado: +%.1fm para frente." % forward_dist)


func _on_noclip_toggled(active: bool) -> void:
	if local_player and local_player.has_method("set_noclip"):
		local_player.set_noclip(active)
		print("[HACK TEST] No-Clip: ", "ATIVADO (Colisao desligada)" if active else "DESATIVADO")


func _on_flyhack_requested(altitude_offset: float) -> void:
	if local_player and local_player.has_method("apply_flyhack"):
		local_player.apply_flyhack(altitude_offset)
		print("[HACK TEST] Flyhack disparado: +%.1fm vertical." % altitude_offset)


func _on_snapback_received(seq: int, _pos: Vector3, _rot: Vector3, reason: int, _replay: Array) -> void:
	var reason_str = "Violacao de Velocidade" if reason == 1 else (
		"Violacao de Obstaculo/NavMesh" if reason == 2 else "Violacao de Altitude Solo"
	)
	if _debug_hud and _debug_hud.has_method("increment_snapback_counter"):
		_debug_hud.increment_snapback_counter("Seq #%d (%s)" % [seq, reason_str])
	print("[ANTI-CHEAT] Snapback recebido do servidor! Seq: %d | Motivo: %s" % [seq, reason_str])
