## @file server_orchestrator.gd
## @path res://src/server/server_orchestrator.gd
##
## @description
## Orquestrador do Servidor Autoritativo Headless Godotage II (Clean Architecture).
## Carrega o mundo de física em memória RAM pura (sem nós 3D/GPU) e gerencia
## a autoridade de movimento e rede QuanticNet.
##
## @created 2026-08-22
## @updated 2026-08-22
##
## @author Leonardo S. Badaró
extends Node

const ServerWorldManagerClass = preload("res://src/infrastructure/server_world_manager.gd")
const QuanticNetServerAdapterClass = preload("res://src/adapters/quantic_net_server_adapter.gd")
const ChunkResourceAdapterClass = preload("res://src/adapters/chunk_resource_adapter.gd")

const DEFAULT_MAPS_PATH: String = "res://assets/maps"
const DEFAULT_PORT: int = 7777
const DEFAULT_MAX_PLAYERS: int = 1000
const DEFAULT_SECRET: String = "DEV_LOCAL_SECRET_CHANGE_ME"

var _server_world: RefCounted
var _server_adapter: RefCounted
var _resource_adapter: RefCounted


func _ready() -> void:
	print("=======================================================")
	print("[SERVER] Iniciando Servidor Autoritativo Godotage II...")
	print("=======================================================")
	start_server()


func start_server() -> void:
	_resource_adapter = ChunkResourceAdapterClass.new(DEFAULT_MAPS_PATH)
	_server_world = ServerWorldManagerClass.new(DEFAULT_MAPS_PATH)
	_server_adapter = QuanticNetServerAdapterClass.new()

	var chunks = _resource_adapter.get_available_chunks()
	for c_name in chunks:
		var ok = _server_world.load_server_chunk(c_name)
		if ok:
			print("[SERVER] Chunk carregado para autoridade física: %s" % c_name)

	if is_inside_tree():
		var qn = get_node_or_null("/root/QuanticNet")
		if qn and qn.has_method("host"):
			var args = OS.get_cmdline_user_args()
			var use_netem = "--netem" in args
			qn.host(DEFAULT_PORT, DEFAULT_MAX_PLAYERS, DEFAULT_SECRET, use_netem)
			print("[SERVER] QuanticNet host iniciado na porta %d." % DEFAULT_PORT)
	else:
		print("[SERVER] Modo Standalone ativo (fora da árvore de cena).")


func get_server_world() -> RefCounted:
	return _server_world


func get_server_adapter() -> RefCounted:
	return _server_adapter
