## @file main.gd
## @path res://main.gd
##
## @description
## Ponto de entrada e Composition Root do projeto godot_age_ii (Godotage II / Lineage II MMO).
## Orquestra o servidor dedicado headless (física e autoridade) ou o cliente gráfico
## (streaming 3D, Shaders de terreno/oceano, static meshes, atmosfera, avatar e DebugHUD).
##
## @created 2026-08-18
## @updated 2026-08-19
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

const PORT := 4242
const SECRET := "secret"
const KNOWN_CHUNKS := ["16_24", "16_25", "17_24", "17_25"]
const DEFAULT_CHUNK := "16_24"

# Ponto de Spawn na entrada da colina da Praça de Talking Island (solo a -300.5m, spawn 5.5m no ar)
const SPAWN_POS := Vector3(-5410.0, -295.0, 20715.0)

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


func _init() -> void:
	_resource_adapter = ChunkResourceAdapterClass.new("res://assets/maps")
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

	_server_world = ServerWorldManagerClass.new("res://assets/maps")
	for c_name in KNOWN_CHUNKS:
		if _resource_adapter.chunk_exists(c_name):
			_server_world.load_server_chunk(c_name)
			print("[SERVER] Chunk carregado para autoridade física: %s" % c_name)

	_server_adapter = QuanticNetServerAdapterClass.new()

	if is_inside_tree():
		var qn = get_node_or_null("/root/QuanticNet")
		if qn and qn.has_method("host"):
			var res = qn.host(PORT, SECRET)
			if res == OK:
				print("[SERVER] QuanticNet host ativo na porta: %d" % PORT)
		else:
			print("[SERVER] Modo Standalone ativo (sem QuanticNet autoload).")
	else:
		print("[SERVER] Modo Standalone ativo (fora da árvore de cena).")


func _start_client() -> void:
	DisplayServer.window_set_title("godot_age_ii [CLIENT - Lineage II 3D]")
	print("\n=======================================================")
	print("[CLIENT] Iniciando Cliente Gráfico Godotage II...")
	print("=======================================================\n")

	# 1. Servidor local embutido para amostragem matemática de física
	_server_world = ServerWorldManagerClass.new("res://assets/maps")
	for c_name in KNOWN_CHUNKS:
		if _resource_adapter.chunk_exists(c_name):
			_server_world.load_server_chunk(c_name)

	# 2. Configura Gerenciador de Streaming do Mundo
	_world_chunk_manager = WorldChunkManagerClass.new("res://assets/maps", 1500.0)
	_world_chunk_manager.name = "WorldChunkManager"
	add_child(_world_chunk_manager)

	for c_name in KNOWN_CHUNKS:
		if _resource_adapter.chunk_exists(c_name):
			_world_chunk_manager.register_chunk(c_name)

	# 3. Oceano desativado temporariamente para debug visual puro
	# _world_chunk_manager.setup_ocean(-320.0, SPAWN_POS)

	# 4. Configura Atmosfera e Iluminação Solar
	_setup_environment(DEFAULT_CHUNK)

	# 5. Instancia Avatar do Jogador
	_local_player = PlayerAvatarClass.new()
	_local_player.name = "PlayerAvatar"
	_local_player.position = SPAWN_POS
	add_child(_local_player)

	# Força streaming inicial ao redor do spawn
	_world_chunk_manager.update_streaming(_local_player.position)

	# 6. Instancia HUD de Telemetria
	_debug_hud = DebugHUDClass.new()
	_debug_hud.name = "DebugHUD"
	add_child(_debug_hud)

	# 7. Conexão de Rede Opcional
	if is_inside_tree():
		var qn = get_node_or_null("/root/QuanticNet")
		if qn and qn.has_method("join"):
			var args = OS.get_cmdline_user_args()
			var use_netem = "--netem" in args
			qn.join("127.0.0.1", PORT, SECRET, use_netem)


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
		_world_environment.environment.fog_enabled = false # Debug visual sem névoa


var _last_stream_pos: Vector3 = Vector3(999999, 999999, 999999)


func _process(_delta: float) -> void:
	if _is_server or not _local_player:
		return

	# Atualiza streaming apenas se o jogador se moveu mais de 10 metros
	if _world_chunk_manager and _local_player.position.distance_squared_to(_last_stream_pos) > 100.0:
		_last_stream_pos = _local_player.position
		_world_chunk_manager.update_streaming(_local_player.position)

	# Atualiza telemetria do HUD
	if _debug_hud and _server_world:
		var c_name = _server_world.get_chunk_name_at(_local_player.position.x, _local_player.position.z)
		var alt_info = _server_world.get_altitude_at(_local_player.position.x, _local_player.position.z)
		var ground_alt = float(alt_info.get("altitude", 0.0))
		_debug_hud.update_telemetry(_local_player.position, c_name, ground_alt)


func _input(event: InputEvent) -> void:
	if _is_server:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# Tecla F2: Alterna Modo Wireframe da Engine
		if event.keycode == KEY_F2 or event.physical_keycode == KEY_F2:
			var vp = get_viewport()
			if vp:
				if vp.debug_draw == Viewport.DEBUG_DRAW_DISABLED:
					vp.debug_draw = Viewport.DEBUG_DRAW_WIREFRAME
					print("[DEBUG] Viewport Wireframe: ATIVADO")
				elif vp.debug_draw == Viewport.DEBUG_DRAW_WIREFRAME:
					vp.debug_draw = Viewport.DEBUG_DRAW_OVERDRAW
					print("[DEBUG] Viewport Overdraw: ATIVADO")
				else:
					vp.debug_draw = Viewport.DEBUG_DRAW_DISABLED
					print("[DEBUG] Viewport Debug: DESATIVADO")
		# Tecla F3: Alterna HUD
		elif event.keycode == KEY_F3 or event.physical_keycode == KEY_F3:
			if _debug_hud:
				_debug_hud.toggle_visibility()
				print("[DEBUG] HUD Visibilidade: ", "LIGADA" if _debug_hud.visible else "OCULTA")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var qn = get_node_or_null("/root/QuanticNet")
		if qn and qn.has_method("disconnect_net"):
			qn.disconnect_net(true)
		get_tree().quit()