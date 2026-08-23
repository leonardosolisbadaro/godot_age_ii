## @file telemetry_panel.gd
## @path res://src/debug/panels/telemetry_panel.gd
##
## @description
## Painel/Janela de telemetria e diagnostico de rede em tempo real da Mini-IDE.
## Herda diretamente de DebugWindow e exibe RTT (Ping), Jitter, status da conexao
## e ID de peer local atuando como observador desacoplado dos sinais do QuanticNetClientAdapter.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
class_name TelemetryPanel
extends DebugWindowClass

# ==============================================================================
# DEPENDÊNCIAS PRELOAD
# ==============================================================================

const DebugWindowClass = preload("res://src/debug/debug_window.gd")
const QuanticNetClientAdapterClass = preload(
	"res://src/client/adapters/quantic_net_client_adapter.gd"
)

# ==============================================================================
# CONSTANTES DE FORMATAÇÃO E CORES (DEVTOOL MUTED)
# ==============================================================================

const COLOR_CONNECTED: Color = Color(0.35, 0.85, 0.45)
const COLOR_CONNECTING: Color = Color(0.9, 0.8, 0.3)
const COLOR_DISCONNECTED: Color = Color(0.9, 0.4, 0.35)
const COLOR_NEUTRAL: Color = Color(0.75, 0.78, 0.82)
const COLOR_LABEL_TITLE: Color = Color(0.55, 0.58, 0.65)

# ==============================================================================
# ELEMENTOS VISUAIS ESPECÍFICOS
# ==============================================================================

var _status_label: Label
var _peer_id_label: Label
var _ping_label: Label
var _jitter_label: Label
var _offset_label: Label
var _packet_stats_label: Label

# ==============================================================================
# ESTADO DE TELEMETRIA
# ==============================================================================

var _client_adapter: QuanticNetClientAdapterClass = null
var _last_rtt: float = 0.0
var _current_rtt: float = 0.0
var _jitter: float = 0.0
var _server_offset: float = 0.0
var _pong_count: int = 0
var _min_rtt: float = 999999.0
var _max_rtt: float = 0.0
var _avg_rtt: float = 0.0
var _rtt_sum: float = 0.0


func _init() -> void:
	super._init("Telemetria de Rede", 340.0)
	_update_labels()


func _ready() -> void:
	super._ready()
	_update_labels()


## Conecta este painel a um adaptador de rede cliente para receber telemetria.
func setup(client_adapter: QuanticNetClientAdapterClass) -> void:
	if _client_adapter != null:
		_disconnect_signals()

	_client_adapter = client_adapter
	if _client_adapter != null:
		_connect_signals()
		_update_labels()


func _exit_tree() -> void:
	_disconnect_signals()

# ==============================================================================
# CONSTRUÇÃO DO CONTEÚDO ESPECÍFICO (OVERRIDE)
# ==============================================================================


func _build_content() -> void:
	if _status_label != null or _content_vbox == null:
		return

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_content_vbox.add_child(_status_label)

	var sep = HSeparator.new()
	_content_vbox.add_child(sep)

	_peer_id_label = Label.new()
	_peer_id_label.name = "PeerIdLabel"
	_content_vbox.add_child(_peer_id_label)

	_ping_label = Label.new()
	_ping_label.name = "PingLabel"
	_content_vbox.add_child(_ping_label)

	_jitter_label = Label.new()
	_jitter_label.name = "JitterLabel"
	_content_vbox.add_child(_jitter_label)

	_offset_label = Label.new()
	_offset_label.name = "OffsetLabel"
	_content_vbox.add_child(_offset_label)

	_packet_stats_label = Label.new()
	_packet_stats_label.name = "PacketStatsLabel"
	_content_vbox.add_child(_packet_stats_label)

# ==============================================================================
# ATUALIZAÇÃO REATIVA DE DADOS
# ==============================================================================


func _update_labels() -> void:
	if _status_label == null:
		return

	if _client_adapter == null:
		_status_label.text = "Status: SEM ADAPTADOR"
		_status_label.add_theme_color_override("font_color", COLOR_DISCONNECTED)
		_peer_id_label.text = "Peer ID Local: --"
		_ping_label.text = "Ping (RTT): -- ms"
		_jitter_label.text = "Jitter: -- ms"
		_offset_label.text = "Server Offset: -- ms"
		_packet_stats_label.text = "Amostras Pong: 0"
		return

	var is_connected_to_server = _client_adapter.is_connected_to_server()
	var state = _client_adapter.get_connection_state()
	var peer_id = _client_adapter.get_local_peer_id()

	match state:
		QuanticNetClientAdapterClass.ConnectionState.CONNECTED:
			_status_label.text = "Status: CONECTADO"
			_status_label.add_theme_color_override("font_color", COLOR_CONNECTED)
		QuanticNetClientAdapterClass.ConnectionState.CONNECTING:
			_status_label.text = "Status: CONECTANDO..."
			_status_label.add_theme_color_override("font_color", COLOR_CONNECTING)
		QuanticNetClientAdapterClass.ConnectionState.AUTHENTICATING:
			_status_label.text = "Status: AUTENTICANDO..."
			_status_label.add_theme_color_override("font_color", COLOR_CONNECTING)
		QuanticNetClientAdapterClass.ConnectionState.FAILED:
			_status_label.text = "Status: FALHA NA CONEXAO"
			_status_label.add_theme_color_override("font_color", COLOR_DISCONNECTED)
		_:
			_status_label.text = "Status: DESCONECTADO"
			_status_label.add_theme_color_override("font_color", COLOR_DISCONNECTED)

	_peer_id_label.text = "Peer ID Local: %d" % peer_id if is_connected_to_server else "Peer ID Local: --"
	_ping_label.text = "Ping (RTT): %.1f ms" % _current_rtt if is_connected_to_server else "Ping (RTT): -- ms"
	_jitter_label.text = "Jitter: %.1f ms" % _jitter if is_connected_to_server else "Jitter: -- ms"
	_offset_label.text = "Server Offset: %.1f ms" % _server_offset if is_connected_to_server else "Server Offset: -- ms"

	if _pong_count > 0 and is_connected_to_server:
		_packet_stats_label.text = "Amostras Pong: %d (Min: %.1f / Max: %.1f / Med: %.1f ms)" % [
			_pong_count,
			_min_rtt,
			_max_rtt,
			_avg_rtt,
		]
	else:
		_packet_stats_label.text = "Amostras Pong: 0"

# ==============================================================================
# MANIPULADORES DE SINAIS DO ADAPTADOR
# ==============================================================================


func _connect_signals() -> void:
	if _client_adapter == null:
		return

	if not _client_adapter.pong_received.is_connected(_on_pong_received):
		_client_adapter.pong_received.connect(_on_pong_received)

	if not _client_adapter.connection_state_changed.is_connected(_on_connection_state_changed):
		_client_adapter.connection_state_changed.connect(_on_connection_state_changed)

	if not _client_adapter.connected_to_server.is_connected(_on_connected):
		_client_adapter.connected_to_server.connect(_on_connected)

	if not _client_adapter.disconnected_from_server.is_connected(_on_disconnected):
		_client_adapter.disconnected_from_server.connect(_on_disconnected)


func _disconnect_signals() -> void:
	if _client_adapter == null:
		return

	if _client_adapter.pong_received.is_connected(_on_pong_received):
		_client_adapter.pong_received.disconnect(_on_pong_received)

	if _client_adapter.connection_state_changed.is_connected(_on_connection_state_changed):
		_client_adapter.connection_state_changed.disconnect(_on_connection_state_changed)

	if _client_adapter.connected_to_server.is_connected(_on_connected):
		_client_adapter.connected_to_server.disconnect(_on_connected)

	if _client_adapter.disconnected_from_server.is_connected(_on_disconnected):
		_client_adapter.disconnected_from_server.disconnect(_on_disconnected)


func _on_pong_received(rtt: float, offset: float) -> void:
	_last_rtt = _current_rtt
	_current_rtt = rtt
	_server_offset = offset

	if _pong_count > 0:
		_jitter = absf(_current_rtt - _last_rtt)

	_pong_count += 1
	_rtt_sum += rtt
	_avg_rtt = _rtt_sum / float(_pong_count)
	_min_rtt = minf(_min_rtt, rtt)
	_max_rtt = maxf(_max_rtt, rtt)

	_update_labels()


func _on_connection_state_changed(_new_state: int) -> void:
	_update_labels()


func _on_connected() -> void:
	_update_labels()


func _on_disconnected() -> void:
	_pong_count = 0
	_rtt_sum = 0.0
	_current_rtt = 0.0
	_last_rtt = 0.0
	_jitter = 0.0
	_min_rtt = 999999.0
	_max_rtt = 0.0
	_avg_rtt = 0.0
	_update_labels()

# ==============================================================================
# MÉTODOS DE CONSULTA PARA TESTES
# ==============================================================================


func get_current_rtt() -> float:
	return _current_rtt


func get_jitter() -> float:
	return _jitter


func get_pong_count() -> int:
	return _pong_count
