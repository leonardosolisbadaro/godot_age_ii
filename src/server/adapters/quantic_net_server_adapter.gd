## @file quantic_net_server_adapter.gd
## @path res://src/server/adapters/quantic_net_server_adapter.gd
##
## @description
## Adaptador de interface entre o servidor autoritativo e o plugin QuanticNet.
## Responsável por iniciar/parar o host UDP bare-metal (sem restrição DTLS para WAN),
## monitorar peers conectados e gerenciar o ciclo de vida da sessão de rede.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
class_name QuanticNetServerAdapter
extends RefCounted

# ==============================================================================
# DEPENDÊNCIAS PRELOAD
# ==============================================================================

const NetworkConstantsClass = preload("res://src/core/domain/network_constants.gd")

# ==============================================================================
# SINAIS PÚBLICOS DE CICLO DE VIDA DO SERVIDOR
# ==============================================================================

signal server_started(port: int, bind_ip: String)
signal server_stopped()
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal peer_rejected(peer_id: int, reason: String, strikes: int)
signal state_received(owner_id: int, pos: Vector3, rot: Vector3, custom: int)

# ==============================================================================
# ESTADO INTERNO
# ==============================================================================

var _is_active: bool = false
var _port: int = NetworkConstantsClass.DEFAULT_PORT
var _bind_ip: String = NetworkConstantsClass.DEFAULT_BIND_IP
var _connected_peers: Array[int] = []
var _quantic_net: Node = null


func _init(quantic_net_instance: Node = null) -> void:
	if quantic_net_instance != null:
		_quantic_net = quantic_net_instance
	else:
		_quantic_net = _resolve_quantic_net()

	_connect_quantic_net_signals()

# ==============================================================================
# CONTROLE DE CICLO DE VIDA DO SERVIDOR
# ==============================================================================

## Inicia o servidor dedicado escutando na porta e IP especificados.
## Por padrão, 'enable_dtls' é false para suportar conexões UDP diretas entre redes distintas (WAN).
func start_server(
	port: int = NetworkConstantsClass.DEFAULT_PORT,
	bind_ip: String = NetworkConstantsClass.DEFAULT_BIND_IP,
	max_peers: int = NetworkConstantsClass.DEFAULT_MAX_PEERS,
	secret: String = NetworkConstantsClass.DEFAULT_SECRET,
	enable_dtls: bool = NetworkConstantsClass.DEFAULT_ENABLE_DTLS,
	config_overrides: Dictionary = { },
) -> int:
	if _is_active:
		push_warning("[QuanticNetServerAdapter] Servidor ja esta em execucao.")
		return OK

	_port = port
	_bind_ip = bind_ip
	_connected_peers.clear()

	var config: Dictionary = {
		NetworkConstantsClass.KEY_ENABLE_DTLS: enable_dtls,
		NetworkConstantsClass.KEY_SERVER_TICK_RATE: NetworkConstantsClass.DEFAULT_SERVER_TICK_RATE,
		NetworkConstantsClass.KEY_MAX_STRIKES: NetworkConstantsClass.DEFAULT_MAX_STRIKES,
		NetworkConstantsClass.KEY_POSITION_MODE: NetworkConstantsClass.POSITION_MODE_FLOAT32,
		NetworkConstantsClass.KEY_WORLD_BOUNDS: NetworkConstantsClass.DEFAULT_WORLD_BOUNDS,
		NetworkConstantsClass.KEY_CULL_RADIUS: NetworkConstantsClass.DEFAULT_CULL_RADIUS,
		NetworkConstantsClass.KEY_ENTITY_AURA: NetworkConstantsClass.DEFAULT_ENTITY_AURA,
	}

	for k in config_overrides.keys():
		config[k] = config_overrides[k]

	var qn = _get_quantic_net()
	if qn == null:
		push_error("[QuanticNetServerAdapter] QuanticNet singleton nao encontrado.")
		return FAILED

	var err: int = qn.host(port, secret, bind_ip, max_peers, config)
	if err == OK:
		_is_active = true
		server_started.emit(port, bind_ip)
		print(
			"[QuanticNetServerAdapter] Host UDP ativo em %s:%d (DTLS=%s, MaxPeers=%d)"
			% [bind_ip, port, enable_dtls, max_peers]
		)
	else:
		_is_active = false
		push_error("[QuanticNetServerAdapter] Falha ao iniciar host UDP. Codigo de erro: %d" % err)

	return err


## Interrompe o servidor e desconecta todos os peers ativos.
func stop_server() -> void:
	if not _is_active:
		return

	var qn = _get_quantic_net()
	if qn != null and qn.has_method("disconnect_net"):
		qn.disconnect_net()

	_is_active = false
	_connected_peers.clear()
	server_stopped.emit()
	print("[QuanticNetServerAdapter] Servidor encerrado.")


## Retorna se o servidor está ativo.
func is_server_active() -> bool:
	return _is_active


## Retorna a lista de IDs de peers atualmente conectados.
func get_connected_peers() -> Array[int]:
	return _connected_peers.duplicate()


## Retorna a porta em que o host está operando.
func get_port() -> int:
	return _port


## Retorna o IP de bind.
func get_bind_ip() -> String:
	return _bind_ip

# ==============================================================================
# MANIPULADORES DE SINAIS DO QUANTICNET
# ==============================================================================

func _connect_quantic_net_signals() -> void:
	var qn = _get_quantic_net()
	if qn == null:
		return

	if qn.has_signal("peer_joined") and not qn.peer_joined.is_connected(_on_qn_peer_joined):
		qn.peer_joined.connect(_on_qn_peer_joined)

	if qn.has_signal("peer_left") and not qn.peer_left.is_connected(_on_qn_peer_left):
		qn.peer_left.connect(_on_qn_peer_left)

	if qn.has_signal("peer_rejected") and not qn.peer_rejected.is_connected(_on_qn_peer_rejected):
		qn.peer_rejected.connect(_on_qn_peer_rejected)

	if qn.has_signal("state_received") and not qn.state_received.is_connected(_on_qn_state_received):
		qn.state_received.connect(_on_qn_state_received)


func _on_qn_peer_joined(peer_id: int) -> void:
	if not _connected_peers.has(peer_id):
		_connected_peers.append(peer_id)
	peer_joined.emit(peer_id)
	print(
		"[QuanticNetServerAdapter] Peer conectado: #%d (Total: %d)"
		% [peer_id, _connected_peers.size()]
	)


func _on_qn_peer_left(peer_id: int) -> void:
	_connected_peers.erase(peer_id)
	peer_left.emit(peer_id)
	print(
		"[QuanticNetServerAdapter] Peer desconectado: #%d (Total: %d)"
		% [peer_id, _connected_peers.size()]
	)


func _on_qn_peer_rejected(peer_id: int, reason: String, strikes: int) -> void:
	peer_rejected.emit(peer_id, reason, strikes)
	print(
		"[QuanticNetServerAdapter] Peer rejeitado: #%d (Motivo: %s, Strikes: %d)"
		% [peer_id, reason, strikes]
	)


func _on_qn_state_received(owner_id: int, pos: Vector3, rot: Vector3, custom: int) -> void:
	state_received.emit(owner_id, pos, rot, custom)


func _resolve_quantic_net() -> Node:
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree and (main_loop as SceneTree).root != null:
		var root = (main_loop as SceneTree).root
		if root.has_node(NetworkConstantsClass.AUTOLOAD_NAME):
			return root.get_node(NetworkConstantsClass.AUTOLOAD_NAME)
	return null


func _get_quantic_net() -> Node:
	if _quantic_net != null:
		return _quantic_net
	_quantic_net = _resolve_quantic_net()
	return _quantic_net
