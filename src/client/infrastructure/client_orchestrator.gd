## @file client_orchestrator.gd
## @path res://src/client/infrastructure/client_orchestrator.gd
##
## @description
## Orquestrador do Cliente de Jogo.
## Coordena a inicialização do QuanticNetClientAdapter, estabelece a conexão
## de rede bare-metal UDP, gerencia o streaming 3D de terreno/mundo (WorldChunkManager)
## e a camera livre de inspecao (FlyCamera) e Mini-IDE de desenvolvimento.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
class_name ClientOrchestrator
extends Node3D

# ==============================================================================
# DEPENDÊNCIAS PRELOAD
# ==============================================================================

const QuanticNetClientAdapterClass = preload(
	"res://src/client/adapters/quantic_net_client_adapter.gd"
)
const NetworkConstantsClass = preload("res://src/core/domain/network_constants.gd")
const DebugIdeHostClass = preload("res://src/debug/debug_ide_host.gd")
const WorldChunkManagerClass = preload("res://src/client/infrastructure/world_chunk_manager.gd")
const FlyCameraClass = preload("res://src/client/infrastructure/fly_camera.gd")
const PlayerAvatarViewClass = preload("res://src/client/infrastructure/player_avatar_view.gd")
const KinematicStateClass = preload("res://src/core/domain/kinematic_state.gd")

# ==============================================================================
# ESTADO INTERNO
# ==============================================================================

var _client_adapter: QuanticNetClientAdapterClass = null
var _debug_ide_host: CanvasLayer = null
var _world_chunk_manager: WorldChunkManagerClass = null
var _fly_camera: FlyCameraClass = null
var _player_avatar: PlayerAvatarViewClass = null
var _remote_avatars: Dictionary = { } # { peer_id: PlayerAvatarView }
var _is_fly_camera_mode: bool = false
var _auto_connect: bool = true
var is_editor_mode: bool = true
var uncap_fps: bool = true


func _init(auto_connect: bool = true) -> void:
	_auto_connect = auto_connect
	_client_adapter = QuanticNetClientAdapterClass.new()


func _ready() -> void:
	if uncap_fps:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0

	_client_adapter.connected_to_server.connect(_on_connected)
	_client_adapter.disconnected_from_server.connect(_on_disconnected)
	_client_adapter.connection_failed.connect(_on_connection_failed)
	_client_adapter.peer_joined.connect(_on_peer_joined)
	_client_adapter.peer_left.connect(_on_peer_left)
	_client_adapter.pong_received.connect(_on_pong_received)
	_client_adapter.state_received.connect(_on_state_received)
	_client_adapter.snapback_received.connect(_on_snapback_received)

	_setup_world_and_camera()

	if is_editor_mode:
		_mount_debug_ide()

	if _auto_connect:
		start_client()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			_toggle_camera_mode()


func _toggle_camera_mode() -> void:
	_is_fly_camera_mode = not _is_fly_camera_mode
	if _is_fly_camera_mode:
		if _player_avatar:
			_player_avatar.is_active = false
		if _fly_camera and _player_avatar:
			_fly_camera.global_position = _player_avatar.global_position + Vector3(0.0, 10.0, 15.0)
			_fly_camera.current = true
			print("[ClientOrchestrator] Modo de Câmera: FlyCamera (Inspeção Livre).")
	else:
		if _player_avatar:
			_player_avatar.is_active = true
			_player_avatar.make_camera_current()
			print("[ClientOrchestrator] Modo de Câmera: PlayerAvatarView (3ª Pessoa RPG).")


func _process(_delta: float) -> void:
	if _world_chunk_manager != null:
		var focal_pos = Vector3.ZERO
		if _is_fly_camera_mode and _fly_camera != null:
			focal_pos = _fly_camera.global_position
		elif _player_avatar != null:
			focal_pos = _player_avatar.global_position
		_world_chunk_manager.update_streaming(focal_pos)


func _exit_tree() -> void:
	stop_client()

# ==============================================================================
# INICIALIZAÇÃO DE MUNDO 3D E CÂMERA
# ==============================================================================


func _setup_world_and_camera() -> void:
	# 1. Gerenciador de Chunks de Mundo
	_world_chunk_manager = WorldChunkManagerClass.new()
	_world_chunk_manager.name = "WorldChunkManager"
	add_child(_world_chunk_manager)

	# 2. Spawn do Avatar Local do Jogador na Talking Island Village (17_25)
	_player_avatar = PlayerAvatarViewClass.new(true, 1)
	_player_avatar.name = "LocalPlayerAvatar"
	_player_avatar.client_adapter = _client_adapter
	add_child(_player_avatar)
	_player_avatar.teleport(Vector3(-5420.0, -180.0, 20725.0))

	# 3. Câmera Livre de Inspeção (Fly Camera) como alternativa via F3
	_fly_camera = FlyCameraClass.new()
	_fly_camera.name = "FlyCamera"
	_fly_camera.position = Vector3(-5420.0, -180.0, 20725.0)
	_fly_camera.rotation_degrees = Vector3(-15.0, 45.0, 0.0)
	_fly_camera.move_speed = 60.0
	_fly_camera.current = false
	add_child(_fly_camera)

	# Ativa câmera em 3ª pessoa do avatar por padrão
	_player_avatar.make_camera_current()

	# Inicia streaming centrado no avatar
	_world_chunk_manager.update_streaming(_player_avatar.global_position)

# ==============================================================================
# COMANDOS PÚBLICOS DE CONEXÃO
# ==============================================================================


func start_client(
	server_ip: String = NetworkConstantsClass.DEFAULT_SERVER_IP,
	port: int = NetworkConstantsClass.DEFAULT_PORT,
	enable_dtls: bool = NetworkConstantsClass.DEFAULT_ENABLE_DTLS,
	secret: String = NetworkConstantsClass.DEFAULT_SECRET,
) -> int:
	print(
		"[ClientOrchestrator] Conectando ao host %s:%d (DTLS=%s)..."
		% [server_ip, port, enable_dtls]
	)
	return _client_adapter.connect_to_server(server_ip, port, secret, enable_dtls)


func stop_client() -> void:
	if _client_adapter != null:
		_client_adapter.disconnect_from_server()


func get_client_adapter() -> QuanticNetClientAdapterClass:
	return _client_adapter


func is_connected_to_server() -> bool:
	return _client_adapter != null and _client_adapter.is_connected_to_server()


func get_debug_ide_host() -> CanvasLayer:
	return _debug_ide_host


func get_world_chunk_manager() -> WorldChunkManagerClass:
	return _world_chunk_manager


func get_fly_camera() -> FlyCameraClass:
	return _fly_camera


func get_remote_avatars() -> Dictionary:
	return _remote_avatars

# ==============================================================================
# INICIALIZAÇÃO DA MINI-IDE
# ==============================================================================


func _mount_debug_ide() -> void:
	if _debug_ide_host == null:
		_debug_ide_host = DebugIdeHostClass.new()
		add_child(_debug_ide_host)
		_debug_ide_host.setup(_client_adapter)

# ==============================================================================
# MANIPULADORES DE EVENTOS DE REDE
# ==============================================================================


func _on_connected() -> void:
	var local_id = _client_adapter.get_local_peer_id()
	if _player_avatar != null:
		_player_avatar.peer_id = local_id
	print(
		"[ClientOrchestrator] Conexao estabelecida com sucesso! Peer ID: %d"
		% local_id
	)


func _on_disconnected() -> void:
	for peer_id in _remote_avatars.keys():
		_remote_avatars[peer_id].queue_free()
	_remote_avatars.clear()
	print("[ClientOrchestrator] Conexao encerrada com o servidor.")


func _on_connection_failed(err: int) -> void:
	push_error("[ClientOrchestrator] Falha de conexao com o servidor. Codigo: %d" % err)


func _on_peer_joined(peer_id: int) -> void:
	print("[ClientOrchestrator] Notificacao de entrada: Peer #%d" % peer_id)


func _on_peer_left(peer_id: int) -> void:
	if _remote_avatars.has(peer_id):
		_remote_avatars[peer_id].queue_free()
		_remote_avatars.erase(peer_id)
	print("[ClientOrchestrator] Notificacao de saida: Peer #%d" % peer_id)


func _on_pong_received(_rtt: float, _offset: float) -> void:
	pass


func _on_state_received(owner_id: int, pos: Vector3, rot: Vector3, _custom: int) -> void:
	var local_id = _client_adapter.get_local_peer_id()
	if owner_id == local_id:
		return

	if not _remote_avatars.has(owner_id):
		var remote = PlayerAvatarViewClass.new(false, owner_id)
		remote.name = "RemoteAvatar_%d" % owner_id
		add_child(remote)
		remote.teleport(pos)
		_remote_avatars[owner_id] = remote
		print("[ClientOrchestrator] [+] Instanciado Avatar Remoto #%d em %s" % [owner_id, pos])
	else:
		var remote = _remote_avatars[owner_id]
		remote.target_remote_state = KinematicStateClass.new(0, pos, Vector3.ZERO, rot.y, true)


func _on_snapback_received(_seq: int, pos: Vector3, _rot: Vector3, reason: int, _replay: Array) -> void:
	if _player_avatar != null:
		_player_avatar.teleport(pos)
	print("[ClientOrchestrator] [SNAPBACK] Reancorado pelo servidor em %s (Motivo: %d)" % [pos, reason])
