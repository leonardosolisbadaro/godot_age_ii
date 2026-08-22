## @file main.gd
## @path res://main.gd
##
## @description
## Ponto de entrada e Composition Root do projeto godot_age_ii (Godotage II / Lineage II MMO).
## Orquestra o servidor dedicado headless (física e autoridade) ou o cliente gráfico
## (streaming 3D, Shaders de terreno/oceano, static meshes, atmosfera, avatar e DebugHUD).
##
## @created 2026-08-18
## @updated 2026-08-21
##
## @author Leonardo S. Badaró
extends Node3D

const WorldChunkManagerClass = preload("res://src/infrastructure/world_chunk_manager.gd")
const ServerWorldManagerClass = preload("res://src/infrastructure/server_world_manager.gd")
const QuanticNetServerAdapterClass = preload("res://src/adapters/quantic_net_server_adapter.gd")
const PlayerAvatarClass = preload("res://src/infrastructure/player_avatar.gd")
const DebugHUDClass = preload("res://src/infrastructure/debug_hud.gd")
const EnvironmentZoneAdapterClass = preload("res://src/adapters/environment_zone_adapter.gd")
const EnvironmentZoneDataClass = preload("res://src/domain/environment_zone_data.gd")
const ChunkResourceAdapterClass = preload("res://src/adapters/chunk_resource_adapter.gd")
const HeightfieldSamplerClass = preload("res://src/domain/heightfield_sampler.gd")
const TerrainChunkDataClass = preload("res://src/domain/terrain_chunk_data.gd")
const RadiusGizmoNodeClass = preload("res://src/infrastructure/radius_gizmo_node.gd")
const MeshSelectionHighlighterClass = preload(
	"res://src/infrastructure/mesh_selection_highlighter.gd"
)

# ==============================================================================
# CONSTANTES SEMÂNTICAS DE REDE E MUNDO
# ==============================================================================

## @const DEFAULT_PORT (int)
## O que: Porta UDP padrão de escuta e conexão de rede do QuanticNet (4242).
## Porque: Porta padronizada do servidor autoritativo de desenvolvimento.
const DEFAULT_PORT: int = 4242

## @const DEFAULT_SECRET (String)
## O que: Senha de autenticação do protocolo de handshake de rede ("secret").
## Porque: Validação de segurança básica entre peers.
const DEFAULT_SECRET: String = "secret"

## @const DEFAULT_LOCAL_IP (String)
## O que: Endereço IP padrão para conexão local em modo standalone ("127.0.0.1").
## Porque: Loopback padrão de desenvolvimento.
const DEFAULT_LOCAL_IP: String = "127.0.0.1"

## @const MAPS_BASE_PATH (String)
## O que: Caminho raiz para artefatos compilados de mapa ("res://assets/maps").
## Porque: Diretório canônico de assets do Godot 4.
const MAPS_BASE_PATH: String = "res://assets/maps"

## @const FALLBACK_ENV_CHUNK (String)
## O que: Chunk de referência padrão para parâmetros atmosféricos caso nenhum seja detectado ("16_24").
## Porque: Região central de Talking Island Village.
const FALLBACK_ENV_CHUNK: String = "17_25"

## @const SPAWN_ON_MAP (String)
## O que: Identificador do chunk para cálculo dinâmico do ponto de spawn ("16_24").
## Porque: Caso preenchido e não nulo, o spawn será posicionado no centro do chunk e na cota do solo.
# const SPAWN_ON_MAP: String = ""
const SPAWN_ON_MAP: String = "17_25"

## @const SPAWN_POS (Vector3)
## O que: Ponto inicial de spawn de fallback caso SPAWN_ON_MAP seja vazio ou nulo.
## Porque: Ponto de referência em Talking Island (X=-3779.0m, Y=-286.0m, Z=16976.0m).
const SPAWN_POS: Vector3 = Vector3(-3779.0, -286.0, 16976.0)

## @const DEFAULT_STREAMING_RADIUS_METERS (float)
## O que: Raio de visão para streaming de chunks em metros (1500.0m).
## Porque: Cobre os chunks adjacentes suavemente sem sobrecarga de GPU.
const DEFAULT_STREAMING_RADIUS_METERS: float = 1500.0

## @const STREAMING_UPDATE_THRESHOLD_SQ (float)
## O que: Distância ao quadrado mínima percorrida pelo avatar para disparar verificação de streaming (100.0 = 10m).
## Porque: Evita recálculos contínuos a cada frame quando o jogador está quase parado.
const STREAMING_UPDATE_THRESHOLD_SQ: float = 100.0

## @const INITIAL_UNSTREAMED_POS (Vector3)
## O que: Posição sentinela inicial para garantir primeiro disparo de streaming.
## Porque: Força o carregamento na primeira iteração de _process.
const INITIAL_UNSTREAMED_POS: Vector3 = Vector3(999999.0, 999999.0, 999999.0)

# ==============================================================================
# VARIÁVEIS DE ESTADO
# ==============================================================================

var _is_server: bool = false
var _world_chunk_manager: Node3D
var _server_world: RefCounted
var _server_adapter: RefCounted
var _local_player: CharacterBody3D
var _debug_hud: CanvasLayer
var _directional_light: DirectionalLight3D
var _world_environment: WorldEnvironment
var _resource_adapter: RefCounted
var _env_adapter: RefCounted
var _last_stream_pos: Vector3 = INITIAL_UNSTREAMED_POS
var _wireframe_active: bool = false
var _radius_gizmo: Node3D
var _mesh_selection_highlighter: Node3D
var _inspector_radius: float = 40.0
var _inspector_timer: float = 0.0


func _init() -> void:
	_resource_adapter = ChunkResourceAdapterClass.new(MAPS_BASE_PATH)
	_env_adapter = EnvironmentZoneAdapterClass.new()


func _ready() -> void:
	var args = OS.get_cmdline_user_args()
	_is_server = "--server" in args

	if _is_server:
		_start_server()
	else:
		_start_client()


func _start_server() -> void:
	DisplayServer.window_set_title("godot_age_ii [SERVER - Headless]")
	print("\n=======================================================")
	print("[SERVER] Iniciando Servidor Autoritativo Godotage II...")
	print("=======================================================\n")

	_server_world = ServerWorldManagerClass.new(MAPS_BASE_PATH)
	var loaded_chunks = _server_world.load_all_available_chunks()
	for c_name in loaded_chunks:
		print("[SERVER] Chunk carregado para autoridade física: %s" % c_name)

	_server_adapter = QuanticNetServerAdapterClass.new()

	if is_inside_tree():
		var qn = get_node_or_null("/root/QuanticNet")
		if qn and qn.has_method("host"):
			var res = qn.host(DEFAULT_PORT, DEFAULT_SECRET)
			if res == OK:
				print("[SERVER] QuanticNet host ativo na porta: %d" % DEFAULT_PORT)
		else:
			print("[SERVER] Modo Standalone ativo (sem QuanticNet autoload).")
	else:
		print("[SERVER] Modo Standalone ativo (fora da árvore de cena).")


func _start_client() -> void:
	DisplayServer.window_set_title("godot_age_ii [CLIENT - Lineage II 3D]")
	print("\n=======================================================")
	print("[CLIENT] Iniciando Cliente Gráfico Godotage II...")
	print("=======================================================\n")

	# 1. Configura Gerenciador de Streaming do Mundo
	_world_chunk_manager = WorldChunkManagerClass.new(
		MAPS_BASE_PATH,
		DEFAULT_STREAMING_RADIUS_METERS,
	)
	_world_chunk_manager.name = "WorldChunkManager"
	add_child(_world_chunk_manager)

	var registered_chunks = _world_chunk_manager.register_available_chunks()

	# 2. Configura Atmosfera e Iluminação Solar
	var primary_chunk = registered_chunks[0] if not registered_chunks.is_empty() else FALLBACK_ENV_CHUNK
	_setup_environment(primary_chunk)

	# 3. Instancia Avatar do Jogador
	_local_player = PlayerAvatarClass.new()
	_local_player.name = "PlayerAvatar"
	_local_player.position = _calculate_spawn_position()
	add_child(_local_player)

	# Força streaming inicial síncrono ao redor do spawn
	_world_chunk_manager.update_streaming(_local_player.position, false)

	# 4. Instancia HUD de Telemetria
	_debug_hud = DebugHUDClass.new()
	_debug_hud.name = "DebugHUD"
	_debug_hud.actor_selected.connect(_on_actor_selected_in_hud)
	_debug_hud.actor_transform_applied.connect(_on_actor_transform_applied)
	_debug_hud.actor_fix_saved.connect(_on_actor_fix_saved)
	_debug_hud.actor_reset_requested.connect(_on_actor_reset_requested)
	add_child(_debug_hud)

	# 5. Instancia Gizmo de Raio 3D e Highlighter de Seleção
	_radius_gizmo = RadiusGizmoNodeClass.new(_inspector_radius)
	_radius_gizmo.name = "RadiusGizmoNode"
	_radius_gizmo.visible = false
	add_child(_radius_gizmo)

	_mesh_selection_highlighter = MeshSelectionHighlighterClass.new()
	_mesh_selection_highlighter.name = "MeshSelectionHighlighter"
	add_child(_mesh_selection_highlighter)

	# 6. Conexão de Rede Opcional
	if is_inside_tree():
		var qn = get_node_or_null("/root/QuanticNet")
		if qn and qn.has_method("join"):
			var args = OS.get_cmdline_user_args()
			var use_netem = "--netem" in args
			qn.join(DEFAULT_LOCAL_IP, DEFAULT_PORT, DEFAULT_SECRET, use_netem)


func _calculate_spawn_position() -> Vector3:
	if not SPAWN_ON_MAP.is_empty() and SPAWN_ON_MAP != "null":
		var meta = _resource_adapter.load_chunk_meta_dict(SPAWN_ON_MAP, true)
		if not meta.is_empty() and meta.has("world_origin_meters"):
			var orig = meta.get("world_origin_meters", [0.0, 0.0, 0.0])
			var sx = float(orig[0])
			var sz = float(orig[2])
			var sy = float(orig[1])

			# Amostragem matemática via HeightfieldSampler pura no cliente (zero dependência de rede/servidor)
			var hf_bytes = _resource_adapter.load_heightfield_bytes(SPAWN_ON_MAP)
			if not hf_bytes.is_empty():
				var chunk_data = TerrainChunkDataClass.new()
				chunk_data.from_meta_dictionary(meta)
				var sampler = HeightfieldSamplerClass.from_chunk_data_and_bytes(
					chunk_data,
					hf_bytes,
				)
				if sampler:
					sy = sampler.get_height_at(sx, sz)
				return Vector3(sx, sy + 1.0, sz)
			return Vector3(sx, sy + 1.0, sz)

	return SPAWN_POS


func _setup_environment(chunk_name: String) -> void:
	var env_recipe = _resource_adapter.load_environment_recipe_dict(chunk_name)
	var env_data = EnvironmentZoneDataClass.new("Talking Island")
	if not env_recipe.is_empty():
		env_data.from_recipe_dictionary(env_recipe)

	# Sol Direcional
	_directional_light = DirectionalLight3D.new()
	_directional_light.name = "SunLight"
	_directional_light.shadow_enabled = true
	add_child(_directional_light)
	_env_adapter.apply_to_directional_light(env_data, _directional_light)

	# Ambiente e Névoa
	_world_environment = WorldEnvironment.new()
	_world_environment.name = "WorldEnvironment"
	add_child(_world_environment)
	_env_adapter.apply_to_world_environment(env_data, _world_environment)
	if _world_environment.environment:
		_world_environment.environment.fog_enabled = false


func _process(delta: float) -> void:
	if _is_server or not _local_player:
		return

	# Atualiza streaming assíncrono em background se o jogador se moveu além do limiar
	if (
		_world_chunk_manager
		and _local_player.position.distance_squared_to(_last_stream_pos) > STREAMING_UPDATE_THRESHOLD_SQ
	):
		_last_stream_pos = _local_player.position
		_world_chunk_manager.update_streaming(_local_player.position, true)

	# Atualiza posição do Gizmo de Raio no mundo
	if _radius_gizmo:
		_radius_gizmo.set_center_position(_local_player.position)

	# Atualiza Inspetor de Atores Próximos se o painel F4 estiver ativo
	if _debug_hud and _debug_hud.is_actor_inspector_open():
		_inspector_timer += delta
		if _inspector_timer >= 0.15:
			_inspector_timer = 0.0
			var nearby = _world_chunk_manager.get_static_actors_in_radius(
				_local_player.position,
				_inspector_radius,
			)
			_debug_hud.update_nearby_actors(nearby, _inspector_radius)

	# Atualiza telemetria do HUD
	if _debug_hud:
		var c_name = ""
		var ground_alt = _local_player.position.y
		if _server_world:
			c_name = _server_world.get_chunk_name_at(
				_local_player.position.x,
				_local_player.position.z,
			)
			var alt_info = _server_world.get_altitude_at(
				_local_player.position.x,
				_local_player.position.z,
			)
			ground_alt = float(alt_info.get("altitude", 0.0))
		else:
			var coords = _get_chunk_indices_at(_local_player.position.x, _local_player.position.z)
			c_name = "%d_%d" % [coords.x, coords.y]

		_debug_hud.update_telemetry(
			_local_player.position,
			c_name,
			ground_alt,
			_wireframe_active,
		)


func _get_chunk_indices_at(world_x: float, world_z: float) -> Vector2i:
	var chunk_w = 2621.44
	var chunk_d = 2621.44
	var cx = 19 + int(floor((world_x + (chunk_w * 0.5)) / chunk_w))
	var cy = 17 + int(floor((world_z + (chunk_d * 0.5)) / chunk_d))
	return Vector2i(cx, cy)


func _input(event: InputEvent) -> void:
	if _is_server:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# Tecla F2: Alterna HUD
		if event.keycode == KEY_F2 or event.physical_keycode == KEY_F2:
			if _debug_hud:
				_debug_hud.toggle_visibility()
				print("[DEBUG] HUD Visibilidade: ", "LIGADA" if _debug_hud.visible else "OCULTA")

		# Tecla F3: Alterna Modo Wireframe Ultraleve Direto no Shader (60 FPS cravados)
		elif event.keycode == KEY_F3 or event.physical_keycode == KEY_F3:
			_wireframe_active = not _wireframe_active
			if _world_chunk_manager:
				_world_chunk_manager.set_wireframe_enabled(_wireframe_active)
			print("[DEBUG] Wireframe (60 FPS): ", "ATIVADO" if _wireframe_active else "DESATIVADO")

		# Tecla F4: Alterna Inspetor de Atores Próximos e Gizmo de Raio
		elif event.keycode == KEY_F4 or event.physical_keycode == KEY_F4:
			if _debug_hud:
				_debug_hud.toggle_actor_inspector()
				var is_open = _debug_hud.is_actor_inspector_open()
				if _radius_gizmo:
					_radius_gizmo.set_gizmo_visible(is_open)
				if is_open:
					var nearby = _world_chunk_manager.get_static_actors_in_radius(
						_local_player.position,
						_inspector_radius,
					)
					_debug_hud.update_nearby_actors(nearby, _inspector_radius)
				else:
					_debug_hud.clear_selection()
					if _mesh_selection_highlighter:
						_mesh_selection_highlighter.clear_highlight()
				print("[DEBUG] Inspetor de Atores (F4): ", "ATIVADO" if is_open else "DESATIVADO")

		# Tecla ESC: Cancela a seleção de ator e limpa o destaque 3D
		elif event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
			if _debug_hud:
				_debug_hud.clear_selection()
			if _mesh_selection_highlighter:
				_mesh_selection_highlighter.clear_highlight()
			print("[DEBUG] Seleção de Ator Cancelada (ESC).")

		# Tecla F5: Alterna Visualização de Colisores de Física (Debug Collision)
		elif event.keycode == KEY_F5 or event.physical_keycode == KEY_F5:
			_toggle_debug_collisions()

		# Tecla F10: Salva o estado atual de corpos d'água na memória para water_volumes_fix.json
		elif event.keycode == KEY_F10 or event.physical_keycode == KEY_F10:
			_save_current_chunk_water_fix()

		# Tecla F12: Alterna Sombras da Luz Solar
		elif event.keycode == KEY_F12 or event.physical_keycode == KEY_F12:
			if _directional_light:
				_directional_light.shadow_enabled = not _directional_light.shadow_enabled
				print(
					"[DEBUG] Sombras Direcionais: ",
					"ATIVADAS" if _directional_light.shadow_enabled else "DESATIVADAS",
				)

	# Ajuste Dinâmico do Raio de Inspeção com Ctrl + Scroll
	elif event is InputEventMouseButton and event.pressed and event.ctrl_pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_inspector_radius = clampf(_inspector_radius + 5.0, 5.0, 100.0)
			if _radius_gizmo:
				_radius_gizmo.set_radius(_inspector_radius)
			if _debug_hud and _debug_hud.is_actor_inspector_open():
				var nearby = _world_chunk_manager.get_static_actors_in_radius(
					_local_player.position,
					_inspector_radius,
				)
				_debug_hud.update_nearby_actors(nearby, _inspector_radius)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_inspector_radius = clampf(_inspector_radius - 5.0, 5.0, 100.0)
			if _radius_gizmo:
				_radius_gizmo.set_radius(_inspector_radius)
			if _debug_hud and _debug_hud.is_actor_inspector_open():
				var nearby = _world_chunk_manager.get_static_actors_in_radius(
					_local_player.position,
					_inspector_radius,
				)
				_debug_hud.update_nearby_actors(nearby, _inspector_radius)


func _on_actor_selected_in_hud(actor_dict: Dictionary) -> void:
	if not _mesh_selection_highlighter:
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
	sc: Vector3
) -> void:
	if not _world_chunk_manager:
		return
	var res = _world_chunk_manager.update_static_actor_transform(actor_name, pos, rot_deg, sc)
	if res.get("found", false) and _mesh_selection_highlighter:
		var mesh = res.get("mesh", null)
		var xform = res.get("transform", Transform3D.IDENTITY)
		var aabb = res.get("aabb", AABB())
		if mesh:
			_mesh_selection_highlighter.highlight_mesh_and_aabb(mesh, xform, aabb)
		else:
			_mesh_selection_highlighter.highlight_aabb(aabb)
		print("[DEBUG] Ator '%s' transform atualizado em tempo real no mundo 3D." % actor_name)


func _on_actor_fix_saved(actor_name: String, pos: Vector3, rot_deg: Vector3, sc: Vector3) -> void:
	if not _world_chunk_manager:
		return
	_on_actor_transform_applied(actor_name, pos, rot_deg, sc)
	var success = _world_chunk_manager.save_actor_fix(actor_name, pos, rot_deg, sc)
	if success:
		print("[DEBUG] chunk_static_actors_fix.json salvo com sucesso para ator '%s'." % actor_name)
	else:
		print("[DEBUG] Falha ao salvar chunk_static_actors_fix.json para ator '%s'." % actor_name)


func _on_actor_reset_requested(actor_name: String) -> void:
	if not _world_chunk_manager:
		return
	var raw = _world_chunk_manager.get_raw_actor_data(actor_name)
	if not raw.is_empty():
		var pos = raw.get("position", Vector3.ZERO)
		var rot = raw.get("rotation_degrees", Vector3.ZERO)
		var sc = raw.get("scale", Vector3.ONE)
		_on_actor_transform_applied(actor_name, pos, rot, sc)
		if _debug_hud:
			var raw_pos = raw.get("raw_position", pos)
			var raw_rot = raw.get("raw_rotation_degrees", rot)
			var raw_sc = raw.get("raw_scale", sc)
			_debug_hud.set_editor_values(raw_pos, raw_rot, raw_sc, "Valores restaurados para o original!")
		print("[DEBUG] Ator '%s' resetado para valores originais." % actor_name)


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


func _refresh_collision_shapes_recursive(node: Node) -> void:
	if not node:
		return

	if node is CollisionShape3D:
		var s = node.shape
		node.shape = null
		node.shape = s

	for child in node.get_children():
		_refresh_collision_shapes_recursive(child)


func _save_current_chunk_water_fix() -> void:
	if not _local_player or not _world_chunk_manager:
		return

	var current_chunk = ""
	if _server_world:
		current_chunk = _server_world.get_chunk_name_at(
			_local_player.position.x,
			_local_player.position.z,
		)
	else:
		var coords = _get_chunk_indices_at(_local_player.position.x, _local_player.position.z)
		current_chunk = "%d_%d" % [coords.x, coords.y]

	if current_chunk.is_empty():
		current_chunk = FALLBACK_ENV_CHUNK

	var success = _world_chunk_manager.save_water_volumes_fix_for_chunk(current_chunk)
	if success:
		print(
			"[DEBUG] [F4] water_volumes_fix.json salvo com sucesso para o chunk '%s'."
			% current_chunk
		)
	else:
		print(
			"[DEBUG] [F4] Falha ao salvar water_volumes_fix.json para o chunk '%s'." % current_chunk
		)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var qn = get_node_or_null("/root/QuanticNet")
		if qn and qn.has_method("disconnect_net"):
			qn.disconnect_net(true)
		get_tree().quit()
