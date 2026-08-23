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
const ServerChunkManagerClass = preload("res://src/server/infrastructure/server_chunk_manager.gd")
const ValidatePlayerMovementUseCaseClass = preload(
	"res://src/server/use_cases/validate_player_movement_use_case.gd"
)
const KinematicStateClass = preload("res://src/core/domain/kinematic_state.gd")
const PlayerStatsClass = preload("res://src/core/domain/player_stats.gd")

# ==============================================================================
# ESTADO INTERNO
# ==============================================================================

var _server_adapter: QuanticNetServerAdapterClass = null
var _server_chunk_manager: ServerChunkManagerClass = null
var _peer_states: Dictionary = { } # { peer_id: { "last_state": KinematicState, "stats": PlayerStats, "last_time": float } }
var _auto_start: bool = true


func _init(auto_start: bool = true) -> void:
	_auto_start = auto_start
	_server_adapter = QuanticNetServerAdapterClass.new()
	_server_chunk_manager = ServerChunkManagerClass.new()


func _ready() -> void:
	_server_adapter.peer_joined.connect(_on_peer_joined)
	_server_adapter.peer_left.connect(_on_peer_left)
	_server_adapter.peer_rejected.connect(_on_peer_rejected)
	_server_adapter.state_received.connect(_on_state_received)

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
	var stats = PlayerStatsClass.new()
	_peer_states[peer_id] = {
		"last_state": null,
		"stats": stats,
		"last_time": Time.get_ticks_msec() / 1000.0,
	}
	print("[ServerOrchestrator] [+] Peer #%d autenticado e registrado no mundo." % peer_id)


func _on_peer_left(peer_id: int) -> void:
	_peer_states.erase(peer_id)
	print("[ServerOrchestrator] [-] Peer #%d desconectado do mundo." % peer_id)


func _on_peer_rejected(peer_id: int, reason: String, strikes: int) -> void:
	print(
		"[ServerOrchestrator] [!] Peer #%d rejeitado pelo QuanticNet (Motivo: %s, Strikes: %d)"
		% [peer_id, reason, strikes]
	)


func _on_state_received(owner_id: int, pos: Vector3, rot: Vector3, _custom: int) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	if not _peer_states.has(owner_id):
		var stats = PlayerStatsClass.new()
		_peer_states[owner_id] = {
			"last_state": null,
			"stats": stats,
			"last_time": now,
		}

	var info = _peer_states[owner_id]
	var last_st = info["last_state"]
	var stats = info["stats"]
	var dt = now - info["last_time"]
	info["last_time"] = now

	var submitted = KinematicStateClass.new(0, pos, Vector3.ZERO, rot.y, true)
	var val_result = ValidatePlayerMovementUseCaseClass.execute(
		last_st,
		submitted,
		stats,
		dt,
		_server_chunk_manager,
		0.25,
	)

	if val_result["valid"]:
		info["last_state"] = val_result.get("state", submitted)
	else:
		var snap_pos = val_result.get("snapback_pos", last_st.position if last_st else pos)
		print(
			"[ServerOrchestrator] [SNAPBACK] Peer #%d violou regras (%s)! Forcando retorno para %s"
			% [owner_id, val_result["reason"], snap_pos]
		)
		_server_adapter.send_snapback(owner_id, 0, snap_pos, rot, 1, [])
