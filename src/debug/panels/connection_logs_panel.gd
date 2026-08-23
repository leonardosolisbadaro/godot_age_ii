## @file connection_logs_panel.gd
## @path res://src/debug/panels/connection_logs_panel.gd
##
## @description
## Painel/Janela de logs de rede e eventos de conexao em tempo real da Mini-IDE.
## Herda diretamente de DebugWindow e exibe historico colorido de handshakes,
## desconexoes e entradas/saidas de peers via QuanticNetClientAdapter.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
class_name ConnectionLogsPanel
extends DebugWindowClass

# ==============================================================================
# DEPENDÊNCIAS PRELOAD
# ==============================================================================

const DebugWindowClass = preload("res://src/debug/debug_window.gd")
const QuanticNetClientAdapterClass = preload(
	"res://src/client/adapters/quantic_net_client_adapter.gd"
)

# ==============================================================================
# CONSTANTES DE CONFIGURAÇÃO
# ==============================================================================

const MAX_LOG_ENTRIES: int = 100

# ==============================================================================
# ELEMENTOS VISUAIS ESPECÍFICOS
# ==============================================================================

var _log_text: RichTextLabel
var _clear_button: Button
var _client_adapter: QuanticNetClientAdapterClass = null
var _log_entries: Array[String] = []


func _init() -> void:
	super._init("Logs de Rede", 460.0)
	_render_logs()


func _ready() -> void:
	super._ready()
	_render_logs()


## Conecta este painel ao adaptador de rede cliente.
func setup(client_adapter: QuanticNetClientAdapterClass) -> void:
	if _client_adapter != null:
		_disconnect_signals()

	_client_adapter = client_adapter
	if _client_adapter != null:
		_connect_signals()
		log_event("[color=yellow]Adaptador de rede vinculado ao painel de logs.[/color]")


func _exit_tree() -> void:
	_disconnect_signals()

# ==============================================================================
# CONSTRUÇÃO DO CONTEÚDO ESPECÍFICO (OVERRIDE)
# ==============================================================================


func _build_content() -> void:
	if _log_text != null or _content_vbox == null:
		return

	var header_hbox = HBoxContainer.new()
	_content_vbox.add_child(header_hbox)

	var title = Label.new()
	title.text = "Feed de Eventos"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color(0.6, 0.75, 0.9))
	header_hbox.add_child(title)

	_clear_button = Button.new()
	_clear_button.text = "Limpar Logs"
	_clear_button.pressed.connect(clear_logs)
	header_hbox.add_child(_clear_button)

	_log_text = RichTextLabel.new()
	_log_text.name = "LogText"
	_log_text.bbcode_enabled = true
	_log_text.scroll_following = true
	_log_text.custom_minimum_size = Vector2(0, 160)
	_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_child(_log_text)

# ==============================================================================
# REGISTRO DE EVENTOS
# ==============================================================================


## Adiciona uma nova entrada de log formatada com timestamp.
func log_event(bbcode_message: String) -> void:
	var time_dict = Time.get_time_dict_from_system()
	var timestamp = "[color=gray][%02d:%02d:%02d][/color] " % [
		time_dict.hour,
		time_dict.minute,
		time_dict.second,
	]
	var entry = timestamp + bbcode_message

	_log_entries.append(entry)
	if _log_entries.size() > MAX_LOG_ENTRIES:
		_log_entries.pop_front()

	if _log_text != null:
		_render_logs()


## Limpa todo o buffer de logs.
func clear_logs() -> void:
	_log_entries.clear()
	if _log_text != null:
		_log_text.clear()


func _render_logs() -> void:
	if _log_text == null:
		return
	_log_text.clear()
	for entry in _log_entries:
		_log_text.append_text(entry + "\n")

# ==============================================================================
# MANIPULADORES DE SINAIS DO ADAPTADOR
# ==============================================================================


func _connect_signals() -> void:
	if _client_adapter == null:
		return

	if not _client_adapter.connected_to_server.is_connected(_on_connected):
		_client_adapter.connected_to_server.connect(_on_connected)

	if not _client_adapter.disconnected_from_server.is_connected(_on_disconnected):
		_client_adapter.disconnected_from_server.connect(_on_disconnected)

	if not _client_adapter.connection_failed.is_connected(_on_connection_failed):
		_client_adapter.connection_failed.connect(_on_connection_failed)

	if not _client_adapter.peer_joined.is_connected(_on_peer_joined):
		_client_adapter.peer_joined.connect(_on_peer_joined)

	if not _client_adapter.peer_left.is_connected(_on_peer_left):
		_client_adapter.peer_left.connect(_on_peer_left)


func _disconnect_signals() -> void:
	if _client_adapter == null:
		return

	if _client_adapter.connected_to_server.is_connected(_on_connected):
		_client_adapter.connected_to_server.disconnect(_on_connected)

	if _client_adapter.disconnected_from_server.is_connected(_on_disconnected):
		_client_adapter.disconnected_from_server.disconnect(_on_disconnected)

	if _client_adapter.connection_failed.is_connected(_on_connection_failed):
		_client_adapter.connection_failed.disconnect(_on_connection_failed)

	if _client_adapter.peer_joined.is_connected(_on_peer_joined):
		_client_adapter.peer_joined.disconnect(_on_peer_joined)

	if _client_adapter.peer_left.is_connected(_on_peer_left):
		_client_adapter.peer_left.disconnect(_on_peer_left)


func _on_connected() -> void:
	var peer_id = _client_adapter.get_local_peer_id()
	log_event("[color=green][+] Conectado com sucesso ao servidor! ID Local: %d[/color]" % peer_id)


func _on_disconnected() -> void:
	log_event("[color=red][-] Desconectado do servidor.[/color]")


func _on_connection_failed(error_code: int) -> void:
	log_event("[color=red][!] Falha de conexao com o servidor. Erro: %d[/color]" % error_code)


func _on_peer_joined(peer_id: int) -> void:
	log_event("[color=cyan][*] Peer remoto conectado: #%d[/color]" % peer_id)


func _on_peer_left(peer_id: int) -> void:
	log_event("[color=orange][*] Peer remoto desconectado: #%d[/color]" % peer_id)

# ==============================================================================
# MÉTODOS DE CONSULTA PARA TESTES
# ==============================================================================


func get_log_entries_count() -> int:
	return _log_entries.size()
