## @file quantic_net_client_adapter.gd
## @path res://src/client/adapters/quantic_net_client_adapter.gd
##
## @description
## Adaptador de interface entre o cliente de jogo e o plugin QuanticNet.
## Gerencia o ciclo de vida da conexão UDP direta com o servidor (sem DTLS para WAN),
## monitora métricas de telemetria (RTT/Pong) e despacha estados preditos.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
class_name QuanticNetClientAdapter
extends RefCounted

# ==============================================================================
# DEPENDÊNCIAS PRELOAD
# ==============================================================================

const NetworkConstantsClass = preload("res://src/core/domain/network_constants.gd")

# ==============================================================================
# SINAIS PÚBLICOS DE CICLO DE VIDA DO CLIENTE
# ==============================================================================

signal connection_state_changed(new_state: int)
signal connected_to_server()
signal disconnected_from_server()
signal connection_failed(error_code: int)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal pong_received(rtt: float, offset: float)
signal snapback_received(seq: int, pos: Vector3, rot: Vector3, reason: int, replay_inputs: Array)
signal state_received(owner_id: int, pos: Vector3, rot: Vector3, custom: int)

# ==============================================================================
# ENUMS E ESTADOS DE REDE
# ==============================================================================

enum ConnectionState {
	DISCONNECTED = 0,
	CONNECTING = 1,
	AUTHENTICATING = 2,
	CONNECTED = 3,
	FAILED = 4,
}

# ==============================================================================
# ESTADO INTERNO
# ==============================================================================

var _server_ip: String = NetworkConstantsClass.DEFAULT_SERVER_IP
var _port: int = NetworkConstantsClass.DEFAULT_PORT
var _quantic_net: Node = null


func _init(quantic_net_instance: Node = null) -> void:
	if quantic_net_instance != null:
		_quantic_net = quantic_net_instance
	else:
		_quantic_net = _resolve_quantic_net()

	_connect_quantic_net_signals()

# ==============================================================================
# CONTROLE DE CONEXÃO DO CLIENTE
# ==============================================================================

## Conecta ao servidor no IP e porta informados via UDP bare-metal.
func connect_to_server(
	ip: String = NetworkConstantsClass.DEFAULT_SERVER_IP,
	port: int = NetworkConstantsClass.DEFAULT_PORT,
	secret: String = NetworkConstantsClass.DEFAULT_SECRET,
	enable_dtls: bool = NetworkConstantsClass.DEFAULT_ENABLE_DTLS,
	config_overrides: Dictionary = { }
) -> int:
	_server_ip = ip
	_port = port

	var config: Dictionary = {
		NetworkConstantsClass.KEY_ENABLE_DTLS: enable_dtls,
		NetworkConstantsClass.KEY_POSITION_MODE: NetworkConstantsClass.POSITION_MODE_FLOAT32,
		NetworkConstantsClass.KEY_WORLD_BOUNDS: NetworkConstantsClass.DEFAULT_WORLD_BOUNDS,
	}

	for k in config_overrides.keys():
		config[k] = config_overrides[k]

	var qn = _get_quantic_net()
	if qn == null:
		push_error("[QuanticNetClientAdapter] QuanticNet singleton nao encontrado.")
		return FAILED

	print("[QuanticNetClientAdapter] Conectando a %s:%d (DTLS=%s)..." % [ip, port, enable_dtls])
	var err: int = qn.join(ip, port, secret, false, config)
	if err != OK:
		push_error("[QuanticNetClientAdapter] Falha ao iniciar conexao UDP. Erro: %d" % err)
		connection_failed.emit(err)

	return err


## Encerra a conexão com o servidor.
func disconnect_from_server() -> void:
	var qn = _get_quantic_net()
	if qn != null and qn.has_method("disconnect_net"):
		qn.disconnect_net()
	print("[QuanticNetClientAdapter] Desconectado do servidor.")


## Retorna se o cliente está atualmente conectado.
func is_connected_to_server() -> bool:
	var qn = _get_quantic_net()
	if qn != null and qn.has_method("get_state"):
		return qn.get_state() == ConnectionState.CONNECTED
	return false


## Retorna o estado atual da máquina de estados de conexão.
func get_connection_state() -> int:
	var qn = _get_quantic_net()
	if qn != null and qn.has_method("get_state"):
		return qn.get_state()
	return ConnectionState.DISCONNECTED


## Retorna o ID único atribuído a este peer pelo servidor/ENet.
func get_local_peer_id() -> int:
	var qn = _get_quantic_net()
	if qn != null and qn.has_method("get_unique_id"):
		return qn.get_unique_id()
	return NetworkConstantsClass.INVALID_PEER_ID


## Submete o estado previsto local ao servidor via canal nativo QuanticNet.
## O parâmetro 'delta' (dt) deve ser fornecido dinamicamente pelo loop (_physics_process).
func submit_state(
	pos: Vector3,
	rot: Vector3,
	custom: int,
	delta: float,
) -> void:
	var qn = _get_quantic_net()
	if qn != null and qn.has_method("submit_state"):
		qn.submit_state(pos, rot, custom, delta)


## Consulta o estado interpolado de uma entidade remota no buffer C++.
func get_remote_state(owner_id: int) -> Dictionary:
	var qn = _get_quantic_net()
	if qn != null and qn.has_method("get_remote_state"):
		return qn.get_remote_state(owner_id)
	return { }

# ==============================================================================
# MANIPULADORES DE SINAIS DO QUANTICNET
# ==============================================================================

func _connect_quantic_net_signals() -> void:
	var qn = _get_quantic_net()
	if qn == null:
		return

	if qn.has_signal("connection_state_changed") and not qn.connection_state_changed.is_connected(
			_on_qn_state_changed
		):
		qn.connection_state_changed.connect(_on_qn_state_changed)

	if qn.has_signal("peer_joined") and not qn.peer_joined.is_connected(_on_qn_peer_joined):
		qn.peer_joined.connect(_on_qn_peer_joined)

	if qn.has_signal("peer_left") and not qn.peer_left.is_connected(_on_qn_peer_left):
		qn.peer_left.connect(_on_qn_peer_left)

	if qn.has_signal("pong_received") and not qn.pong_received.is_connected(_on_qn_pong_received):
		qn.pong_received.connect(_on_qn_pong_received)

	if qn.has_signal("snapback_received") and not qn.snapback_received.is_connected(
			_on_qn_snapback_received
		):
		qn.snapback_received.connect(_on_qn_snapback_received)

	if qn.has_signal("state_received") and not qn.state_received.is_connected(_on_qn_state_received):
		qn.state_received.connect(_on_qn_state_received)


func _on_qn_state_changed(new_state: int) -> void:
	connection_state_changed.emit(new_state)
	if new_state == ConnectionState.CONNECTED:
		connected_to_server.emit()
		print(
			"[QuanticNetClientAdapter] Conectado com sucesso ao servidor! ID Local: %d"
			% get_local_peer_id()
		)
	elif new_state == ConnectionState.DISCONNECTED or new_state == ConnectionState.FAILED:
		disconnected_from_server.emit()
		print("[QuanticNetClientAdapter] Conexao finalizada ou falha. Estado: %d" % new_state)


func _on_qn_peer_joined(peer_id: int) -> void:
	peer_joined.emit(peer_id)


func _on_qn_peer_left(peer_id: int) -> void:
	peer_left.emit(peer_id)


func _on_qn_pong_received(rtt: float, offset: float) -> void:
	pong_received.emit(rtt, offset)


func _on_qn_snapback_received(
	seq: int,
	pos: Vector3,
	rot: Vector3,
	reason: int,
	replay_inputs: Array,
) -> void:
	snapback_received.emit(seq, pos, rot, reason, replay_inputs)


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
