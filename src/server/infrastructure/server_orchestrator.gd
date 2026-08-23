## @file server_orchestrator.gd
## @path res://src/server/infrastructure/server_orchestrator.gd
##
## @description
## Orquestrador do Servidor Autoritativo Dedicado (Headless).
## Inicializa e coordena o ciclo de vida do QuanticNetServerAdapter,
## gerenciando conexões de rede sem dependências de nós gráficos ou de física 3D pesados.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
class_name ServerOrchestrator
extends Node

# ==============================================================================
# PROPRIEDADES E ADAPTADORES
# ==============================================================================

const QuanticNetServerAdapterClass = preload(
	"res://src/server/adapters/quantic_net_server_adapter.gd"
)
const NetworkConstantsClass = preload("res://src/core/domain/network_constants.gd")

# ==============================================================================
# ESTADO INTERNO
# ==============================================================================

var _server_adapter: QuanticNetServerAdapterClass = null
var _auto_start: bool = true


func _init(auto_start: bool = true) -> void:
	_auto_start = auto_start
	_server_adapter = QuanticNetServerAdapterClass.new()


func _ready() -> void:
	_server_adapter.peer_joined.connect(_on_peer_joined)
	_server_adapter.peer_left.connect(_on_peer_left)
	_server_adapter.peer_rejected.connect(_on_peer_rejected)

	if _auto_start:
		start_server()


func _exit_tree() -> void:
	stop_server()

# ==============================================================================
# COMANDOS PÚBLICOS DE CICLO DE VIDA
# ==============================================================================


func start_server(
	port: int = NetworkConstantsClass.DEFAULT_PORT,
	bind_ip: String = NetworkConstantsClass.DEFAULT_BIND_IP,
	max_peers: int = NetworkConstantsClass.DEFAULT_MAX_PEERS,
	enable_dtls: bool = NetworkConstantsClass.DEFAULT_ENABLE_DTLS,
	secret: String = NetworkConstantsClass.DEFAULT_SECRET,
) -> int:
	print(
		"[ServerOrchestrator] Inicializando Servidor Dedicado em %s:%d (DTLS=%s)..."
		% [bind_ip, port, enable_dtls]
	)
	var err = _server_adapter.start_server(port, bind_ip, max_peers, secret, enable_dtls)
	if err == OK:
		print("[ServerOrchestrator] Servidor Dedicado pronto para receber conexoes.")
	else:
		push_error("[ServerOrchestrator] Falha ao iniciar Servidor. Erro: %d" % err)
	return err


func stop_server() -> void:
	if _server_adapter != null and _server_adapter.is_server_active():
		_server_adapter.stop_server()
		print("[ServerOrchestrator] Servidor finalizado.")


func get_server_adapter() -> QuanticNetServerAdapterClass:
	return _server_adapter


func is_running() -> bool:
	return _server_adapter != null and _server_adapter.is_server_active()

# ==============================================================================
# MANIPULADORES DE EVENTOS
# ==============================================================================


func _on_peer_joined(peer_id: int) -> void:
	print("[ServerOrchestrator] [+] Peer #%d autenticado e registrado no mundo." % peer_id)


func _on_peer_left(peer_id: int) -> void:
	print("[ServerOrchestrator] [-] Peer #%d desconectado do mundo." % peer_id)


func _on_peer_rejected(peer_id: int, reason: String, strikes: int) -> void:
	print(
		"[ServerOrchestrator] [!] Infracao do Peer #%d: %s (Total strikes: %d)"
		% [peer_id, reason, strikes]
	)
