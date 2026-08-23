## @file main.gd
## @path res://main.gd
##
## @description
## Ponto de entrada e despachante da aplicacao (Clean Architecture).
## Roteia a execucao para ServerOrchestrator ou ClientOrchestrator com base
## nos argumentos de linha de comando (--server, --client, --ip, --port).
##
## @created 2026-08-18
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
extends Node

# ==============================================================================
# DEPENDÊNCIAS PRELOAD
# ==============================================================================

const ClientOrchestratorClass = preload("res://src/client/infrastructure/client_orchestrator.gd")
const ServerOrchestratorClass = preload("res://src/server/infrastructure/server_orchestrator.gd")
const NetworkConstantsClass = preload("res://src/core/domain/network_constants.gd")

# ==============================================================================
# CONSTANTES DE CONFIGURAÇÃO LOCAL
# ==============================================================================

const DEFAULT_ENABLE_EDITOR: bool = true

# ==============================================================================
# CONSTANTES DE ARGUMENTOS DE LINHA DE COMANDO (CLI)
# ==============================================================================

const CLI_ARG_SERVER: String = "--server"
const CLI_ARG_DEDICATED: String = "--dedicated"
const CLI_ARG_ENABLE_EDITOR: String = "--enable-editor"
const CLI_ARG_ENABLE_DTLS: String = "--enable-dtls"
const CLI_PREFIX_IP: String = "--ip="
const CLI_PREFIX_PORT: String = "--port="

# ==============================================================================
# ESTADO INTERNO
# ==============================================================================

var _client_orchestrator: Node3D
var _server_orchestrator: Node


func _ready() -> void:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	var main_args: PackedStringArray = OS.get_cmdline_args()
	var all_args: PackedStringArray = user_args + main_args

	var is_server: bool = (CLI_ARG_SERVER in all_args) or (CLI_ARG_DEDICATED in all_args)
	var enable_dtls: bool = (CLI_ARG_ENABLE_DTLS in all_args)

	var enable_editor: bool = DEFAULT_ENABLE_EDITOR
	if CLI_ARG_ENABLE_EDITOR in all_args:
		enable_editor = true

	var ip_val: String = NetworkConstantsClass.DEFAULT_SERVER_IP
	var port_val: int = NetworkConstantsClass.DEFAULT_PORT

	for arg in all_args:
		if arg.begins_with(CLI_PREFIX_IP):
			ip_val = arg.substr(CLI_PREFIX_IP.length())
		elif arg.begins_with(CLI_PREFIX_PORT):
			port_val = arg.substr(CLI_PREFIX_PORT.length()).to_int()

	if is_server:
		_start_server(port_val, NetworkConstantsClass.DEFAULT_BIND_IP, enable_dtls)
	else:
		_start_client(ip_val, port_val, enable_dtls, enable_editor)


func _start_server(
	port: int = NetworkConstantsClass.DEFAULT_PORT,
	bind_ip: String = NetworkConstantsClass.DEFAULT_BIND_IP,
	enable_dtls: bool = NetworkConstantsClass.DEFAULT_ENABLE_DTLS,
	max_peers: int = NetworkConstantsClass.DEFAULT_MAX_PEERS,
) -> void:
	_server_orchestrator = ServerOrchestratorClass.new(false)
	_server_orchestrator.name = "ServerOrchestrator"
	add_child(_server_orchestrator)
	_server_orchestrator.start_server(port, bind_ip, max_peers, enable_dtls)


func _start_client(
	ip: String = NetworkConstantsClass.DEFAULT_SERVER_IP,
	port: int = NetworkConstantsClass.DEFAULT_PORT,
	enable_dtls: bool = NetworkConstantsClass.DEFAULT_ENABLE_DTLS,
	enable_editor: bool = DEFAULT_ENABLE_EDITOR,
) -> void:
	_client_orchestrator = ClientOrchestratorClass.new(false)
	_client_orchestrator.name = "ClientOrchestrator"
	_client_orchestrator.is_editor_mode = enable_editor
	add_child(_client_orchestrator)
	_client_orchestrator.start_client(ip, port, enable_dtls)

# ==============================================================================
# MÉTODOS DE ACESSO E CONTRATO DE TESTES
# ==============================================================================


func get_client_orchestrator() -> Node3D:
	return _client_orchestrator


func get_server_orchestrator() -> Node:
	return _server_orchestrator


func get_server_adapter() -> RefCounted:
	if _server_orchestrator and _server_orchestrator.has_method("get_server_adapter"):
		return _server_orchestrator.get_server_adapter()
	return null


func get_client_adapter() -> RefCounted:
	if _client_orchestrator and _client_orchestrator.has_method("get_client_adapter"):
		return _client_orchestrator.get_client_adapter()
	return null
