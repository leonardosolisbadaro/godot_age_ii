## @file main.gd
## @path res://main.gd
##
## @description
## Ponto de entrada e despachante minimalista da aplicação Godotage II (Clean Architecture).
## Roteia a inicialização para ClientOrchestrator, ServerOrchestrator ou DebugWorldEditor
## com base nos argumentos de execução de linha de comando.
##
## @created 2026-08-18
## @updated 2026-08-22
##
## @author Leonardo S. Badaró
extends Node

const ClientOrchestratorClass = preload("res://src/client/client_orchestrator.gd")
const ServerOrchestratorClass = preload("res://src/server/server_orchestrator.gd")

var _client_orchestrator: Node3D
var _server_orchestrator: Node


func _ready() -> void:
	var user_args = OS.get_cmdline_user_args()
	var main_args = OS.get_cmdline_args()
	var is_server = (
		("--server" in user_args) or ("--server" in main_args) or ("--dedicated" in user_args)
	)
	var no_editor = ("--no-editor" in user_args) or ("--no-editor" in main_args)

	if is_server:
		_start_server()
	else:
		_start_client(not no_editor)


func _start_server() -> void:
	_server_orchestrator = ServerOrchestratorClass.new()
	_server_orchestrator.name = "ServerOrchestrator"
	add_child(_server_orchestrator)
	if not _server_orchestrator.is_inside_tree():
		_server_orchestrator.start_server()


func _start_client(enable_editor: bool = true) -> void:
	_client_orchestrator = ClientOrchestratorClass.new()
	_client_orchestrator.name = "ClientOrchestrator"
	_client_orchestrator.is_editor_mode = enable_editor
	add_child(_client_orchestrator)
	if not _client_orchestrator.is_inside_tree():
		_client_orchestrator.start_client()

# ==============================================================================
# MÉTODOS DE ACESSO E CONTRATO DE TESTES UNITÁRIOS
# ==============================================================================


func get_world_chunk_manager() -> Node3D:
	if _client_orchestrator and _client_orchestrator.has_method("get_world_chunk_manager"):
		return _client_orchestrator.get_world_chunk_manager()
	return null


func get_local_player() -> CharacterBody3D:
	if _client_orchestrator and _client_orchestrator.has_method("get_local_player"):
		return _client_orchestrator.get_local_player()
	return null


func get_server_world() -> RefCounted:
	if _server_orchestrator and _server_orchestrator.has_method("get_server_world"):
		return _server_orchestrator.get_server_world()
	return null


func get_server_adapter() -> RefCounted:
	if _server_orchestrator and _server_orchestrator.has_method("get_server_adapter"):
		return _server_orchestrator.get_server_adapter()
	return null
