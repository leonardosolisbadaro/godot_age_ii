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

# ==============================================================================
# ESTADO INTERNO
# ==============================================================================

var _client_adapter: QuanticNetClientAdapterClass = null
var _debug_ide_host: CanvasLayer = null
var _world_chunk_manager: WorldChunkManagerClass = null
var _fly_camera: FlyCameraClass = null
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

	_setup_world_and_camera()

	if is_editor_mode:
		_mount_debug_ide()

	if _auto_connect:
		start_client()


func _process(_delta: float) -> void:
	if _world_chunk_manager != null and _fly_camera != null:
		_world_chunk_manager.update_streaming(_fly_camera.global_position)


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

	# 2. Câmera Livre de Inspeção (Fly Camera) posicionada na Talking Island Village (17_25)
	_fly_camera = FlyCameraClass.new()
	_fly_camera.name = "FlyCamera"
	_fly_camera.position = Vector3(-5420.0, -180.0, 20725.0)
	_fly_camera.rotation_degrees = Vector3(-15.0, 45.0, 0.0)
	_fly_camera.move_speed = 60.0
	_fly_camera.current = true
	add_child(_fly_camera)

	# Inicia streaming centrado na câmera
	_world_chunk_manager.update_streaming(_fly_camera.global_position)

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
	print(
		"[ClientOrchestrator] Conexao estabelecida com sucesso! Peer ID: %d"
		% _client_adapter.get_local_peer_id()
	)


func _on_disconnected() -> void:
	print("[ClientOrchestrator] Conexao encerrada com o servidor.")


func _on_connection_failed(err: int) -> void:
	push_error("[ClientOrchestrator] Falha de conexao com o servidor. Codigo: %d" % err)


func _on_peer_joined(peer_id: int) -> void:
	print("[ClientOrchestrator] Notificacao de entrada: Peer #%d" % peer_id)


func _on_peer_left(peer_id: int) -> void:
	print("[ClientOrchestrator] Notificacao de saida: Peer #%d" % peer_id)


func _on_pong_received(_rtt: float, _offset: float) -> void:
	pass
