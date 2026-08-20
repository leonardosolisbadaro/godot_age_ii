## @file main.gd
## @path res://main.gd
##
## @description
## Ponto de entrada e Composition Root do projeto godot_age_ii (Godotage II / Lineage II MMO).
## Orquestra o servidor dedicado headless (física e autoridade) ou o cliente gráfico
## (streaming 3D, Shaders de terreno/oceano, static meshes, atmosfera, avatar e DebugHUD).
##
## @created 2026-08-18
## @updated 2026-08-20
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
const FALLBACK_ENV_CHUNK: String = "16_24"

## @const SPAWN_POS (Vector3)
## O que: Ponto inicial de spawn do avatar em Talking Island (X=-6993.0m, Y=-286.0m, Z=19207.0m).
## Porque: Posicionado na entrada da colina da Praça de Talking Island com solo a -300.5m.
const SPAWN_POS: Vector3 = Vector3(-6993.0, -286.0, 19207.0)

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

	# 1. Servidor local embutido para amostragem matemática de física
	_server_world = ServerWorldManagerClass.new(MAPS_BASE_PATH)
	_server_world.load_all_available_chunks()

	# 2. Configura Gerenciador de Streaming do Mundo
	_world_chunk_manager = WorldChunkManagerClass.new(MAPS_BASE_PATH, DEFAULT_STREAMING_RADIUS_METERS)
	_world_chunk_manager.name = "WorldChunkManager"
	add_child(_world_chunk_manager)

	var registered_chunks = _world_chunk_manager.register_available_chunks()

	# 3. Configura Atmosfera e Iluminação Solar
	var primary_chunk = registered_chunks[0] if not registered_chunks.is_empty() else FALLBACK_ENV_CHUNK
	_setup_environment(primary_chunk)

	# 4. Instancia Avatar do Jogador
	_local_player = PlayerAvatarClass.new()
	_local_player.name = "PlayerAvatar"
	_local_player.position = SPAWN_POS
	add_child(_local_player)

	# Força streaming inicial síncrono ao redor do spawn
	_world_chunk_manager.update_streaming(_local_player.position, false)

	# 5. Instancia HUD de Telemetria
	_debug_hud = DebugHUDClass.new()
	_debug_hud.name = "DebugHUD"
	add_child(_debug_hud)

	# 6. Conexão de Rede Opcional
	if is_inside_tree():
		var qn = get_node_or_null("/root/QuanticNet")
		if qn and qn.has_method("join"):
			var args = OS.get_cmdline_user_args()
			var use_netem = "--netem" in args
			qn.join(DEFAULT_LOCAL_IP, DEFAULT_PORT, DEFAULT_SECRET, use_netem)


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


func _process(_delta: float) -> void:
	if _is_server or not _local_player:
		return

	# Atualiza streaming assíncrono em background se o jogador se moveu além do limiar
	if _world_chunk_manager and _local_player.position.distance_squared_to(_last_stream_pos) > STREAMING_UPDATE_THRESHOLD_SQ:
		_last_stream_pos = _local_player.position
		_world_chunk_manager.update_streaming(_local_player.position, true)

	# Atualiza telemetria do HUD
	if _debug_hud and _server_world:
		var c_name = _server_world.get_chunk_name_at(
			_local_player.position.x,
			_local_player.position.z,
		)
		var alt_info = _server_world.get_altitude_at(
			_local_player.position.x,
			_local_player.position.z,
		)
		var ground_alt = float(alt_info.get("altitude", 0.0))
		_debug_hud.update_telemetry(
			_local_player.position,
			c_name,
			ground_alt,
			_wireframe_active,
		)


func _input(event: InputEvent) -> void:
	if _is_server:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# Tecla F2: Alterna Modo Wireframe Ultraleve Direto no Shader (60 FPS cravados)
		if event.keycode == KEY_F2 or event.physical_keycode == KEY_F2:
			_wireframe_active = not _wireframe_active
			if _world_chunk_manager:
				_world_chunk_manager.set_wireframe_enabled(_wireframe_active)
			print("[DEBUG] Wireframe (60 FPS): ", "ATIVADO" if _wireframe_active else "DESATIVADO")

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
