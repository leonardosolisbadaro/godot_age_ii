## @file client_orchestrator.gd
## @path res://src/client/client_orchestrator.gd
##
## @description
## Orquestrador do Cliente Gráfico Godotage II (Clean Architecture).
## Inicializa streaming de mundo, iluminação, avatar do jogador e rede QuanticNet.
##
## @created 2026-08-22
## @updated 2026-08-22
##
## @author Leonardo S. Badaró
extends Node3D

const WorldChunkManagerClass = preload("res://src/infrastructure/world_chunk_manager.gd")
const EnvironmentZoneAdapterClass = preload("res://src/adapters/environment_zone_adapter.gd")
const EnvironmentZoneDataClass = preload("res://src/domain/environment_zone_data.gd")
const TerrainChunkDataClass = preload("res://src/domain/terrain_chunk_data.gd")
const HeightfieldSamplerClass = preload("res://src/domain/heightfield_sampler.gd")
const ChunkResourceAdapterClass = preload("res://src/adapters/chunk_resource_adapter.gd")
const PlayerAvatarClass = preload("res://src/infrastructure/player_avatar.gd")
const DebugWorldEditorClass = preload("res://src/debug/debug_world_editor.gd")

const DEFAULT_STREAMING_RADIUS_METERS: float = 1500.0
const DEFAULT_MAPS_PATH: String = "res://assets/maps"
const FALLBACK_ENV_CHUNK: String = "17_25"
const SPAWN_ON_MAP: String = "17_25"
const STREAMING_UPDATE_INTERVAL_SEC: float = 0.20
const MIN_STREAMING_MOVEMENT_SQ: float = 25.0 # 5 metros ao quadrado
const INITIAL_UNSTREAMED_POS: Vector3 = Vector3(999999.0, 999999.0, 999999.0)

const DEFAULT_LOCAL_IP: String = "127.0.0.1"
const DEFAULT_PORT: int = 7777
const DEFAULT_SECRET: String = "DEV_LOCAL_SECRET_CHANGE_ME"

var is_editor_mode: bool = true

var _world_chunk_manager: Node3D
var _local_player: CharacterBody3D
var _directional_light: DirectionalLight3D
var _world_environment: WorldEnvironment
var _resource_adapter: RefCounted
var _env_adapter: RefCounted
var _debug_world_editor: Node
var _last_stream_pos: Vector3 = INITIAL_UNSTREAMED_POS
var _streaming_timer: float = 0.0


func _ready() -> void:
	print("=======================================================")
	print("[CLIENT] Iniciando Cliente Gráfico Godotage II...")
	print("=======================================================")
	start_client()


func start_client() -> void:
	_resource_adapter = ChunkResourceAdapterClass.new(DEFAULT_MAPS_PATH)
	_env_adapter = EnvironmentZoneAdapterClass.new()

	# 1. Instancia Gerenciador de Chunks de Mundo
	_world_chunk_manager = WorldChunkManagerClass.new(
		DEFAULT_MAPS_PATH,
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

	# 4. Se estiver em modo editor/desenvolvimento, anexa o DebugWorldEditor
	if is_editor_mode:
		_debug_world_editor = DebugWorldEditorClass.new()
		_debug_world_editor.name = "DebugWorldEditor"
		add_child(_debug_world_editor)
		_debug_world_editor.setup(_world_chunk_manager, _local_player, _directional_light)

	# 5. Conexão de Rede Opcional
	if is_inside_tree():
		var qn = get_node_or_null("/root/QuanticNet")
		if qn and qn.has_method("join"):
			var user_args = OS.get_cmdline_user_args()
			var main_args = OS.get_cmdline_args()
			var combined_args = user_args + main_args

			var use_netem = "--netem" in combined_args
			var target_ip = DEFAULT_LOCAL_IP
			var target_port = DEFAULT_PORT

			for i in range(combined_args.size()):
				if (combined_args[i] == "--connect" or combined_args[i] == "-c") and i + 1 < combined_args.size():
					var raw_addr = str(combined_args[i + 1])
					if ":" in raw_addr:
						var parts = raw_addr.split(":")
						target_ip = parts[0]
						target_port = int(parts[1])
					else:
						target_ip = raw_addr
					break

			var config = {
				"enable_dtls": false,
			}
			if not qn.connection_state_changed.is_connected(_on_connection_state_changed):
				qn.connection_state_changed.connect(_on_connection_state_changed)
			if not qn.peer_joined.is_connected(_on_peer_joined):
				qn.peer_joined.connect(_on_peer_joined)

			qn.join(target_ip, target_port, DEFAULT_SECRET, use_netem, config)
			print("[CLIENT] Tentando conectar ao servidor em %s:%d (Bare-Metal UDP)..." % [target_ip, target_port])


func _on_connection_state_changed(state: int) -> void:
	var qn = get_node_or_null("/root/QuanticNet")
	var st_name = qn.get_state_string() if qn and qn.has_method("get_state_string") else str(state)
	print("[CLIENT] Estado da conexao alterado: %s" % st_name)


func _on_peer_joined(peer_id: int) -> void:
	print("[CLIENT] Handshake concluido! Conectado a sessao (Peer ID: %d)." % peer_id)


func _calculate_spawn_position() -> Vector3:
	var target_chunk = SPAWN_ON_MAP if (not SPAWN_ON_MAP.is_empty() and SPAWN_ON_MAP != "null") else FALLBACK_ENV_CHUNK
	var meta = _resource_adapter.load_chunk_meta_dict(target_chunk, true)
	if not meta.is_empty() and meta.has("world_origin_meters"):
		var orig = meta.get("world_origin_meters", [0.0, 0.0, 0.0])
		var sx = float(orig[0])
		var sz = float(orig[2])

		# Ponto de referência central de Talking Island Village em 17_25
		if target_chunk == "17_25":
			sx = -4382.8
			sz = 21947.6

		var hf_bytes = _resource_adapter.load_heightfield_bytes(target_chunk)
		if not hf_bytes.is_empty():
			var chunk_data = TerrainChunkDataClass.new()
			chunk_data.from_meta_dictionary(meta)
			var sampler = HeightfieldSamplerClass.from_chunk_data_and_bytes(chunk_data, hf_bytes)
			if sampler:
				var ground_y = sampler.get_height_at(sx, sz)
				return Vector3(sx, ground_y + 1.8, sz)
		return Vector3(sx, float(orig[1]) + 1.8, sz)

	return Vector3(-4382.8, -225.0, 21947.6)


func _setup_environment(chunk_name: String) -> void:
	_directional_light = DirectionalLight3D.new()
	_directional_light.name = "SunLight"
	_directional_light.shadow_enabled = true
	add_child(_directional_light)

	_world_environment = WorldEnvironment.new()
	_world_environment.name = "WorldEnvironment"
	add_child(_world_environment)

	if _env_adapter:
		var env_data = EnvironmentZoneDataClass.new("ChunkZone_%s" % chunk_name)
		if _resource_adapter:
			var env_recipe = _resource_adapter.load_environment_recipe_dict(chunk_name)
			if not env_recipe.is_empty():
				env_data.from_recipe_dictionary(env_recipe)
		_env_adapter.apply_to_directional_light(env_data, _directional_light)
		_env_adapter.apply_to_world_environment(env_data, _world_environment)


func _physics_process(delta: float) -> void:
	if not _local_player or not _world_chunk_manager:
		return

	# Atualização Periódica de Streaming de Chunks
	_streaming_timer += delta
	if _streaming_timer >= STREAMING_UPDATE_INTERVAL_SEC:
		_streaming_timer = 0.0
		if _local_player.position.distance_squared_to(_last_stream_pos) >= MIN_STREAMING_MOVEMENT_SQ:
			_last_stream_pos = _local_player.position
			_world_chunk_manager.update_streaming(_local_player.position, true)


func get_world_chunk_manager() -> Node3D:
	return _world_chunk_manager


func get_local_player() -> CharacterBody3D:
	return _local_player
