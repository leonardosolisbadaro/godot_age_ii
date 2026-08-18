## @file main.gd
## @path res://main.gd
##
## @description
## Ponto de entrada do projeto godot_age_ii.
## Orquestra a inicialização do Servidor Autoritativo (--server) ou Cliente (--client).
##
## @created 2026-08-18
## @updated 2026-08-18
##
## @author Leonardo S. Badaró (with Gemini 3.7 Flash - High)
extends Node3D

const PORT := 4242
const SECRET := "secret"

var _is_server: bool = false


func _ready() -> void:
	var args = OS.get_cmdline_user_args()
	_is_server = "--server" in args

	if _is_server:
		_start_server()
	else:
		_start_client()


func _start_server() -> void:
	DisplayServer.window_set_title("godot_age_ii [SERVER]")
	print("\n=======================================================")
	print("[SERVER] Servidor Autoritativo Inicializado na Porta %d" % PORT)
	print("=======================================================\n")
	
	var qn = get_node_or_null("/root/QuanticNet")
	if qn and qn.has_method("host"):
		qn.host(PORT, SECRET)
	else:
		push_warning("QuanticNet Autoload nao carregado.")


func _start_client() -> void:
	DisplayServer.window_set_title("godot_age_ii [CLIENT]")
	print("\n=======================================================")
	print("[CLIENT] Cliente Inicializado — Conectando ao Servidor...")
	print("=======================================================")
	
	var qn = get_node_or_null("/root/QuanticNet")
	if qn and qn.has_method("join"):
		var args = OS.get_cmdline_user_args()
		var use_netem = "--netem" in args
		qn.join("127.0.0.1", PORT, SECRET, use_netem)
		get_tree().set_multiplayer(qn.get_tree().get_multiplayer(qn.get_path()), self.get_path())