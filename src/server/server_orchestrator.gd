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
var _peer_states: Dictionary = { }


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
			var config = {
				"use_netem": use_netem,
				"enable_dtls": false,
				"max_strikes": 9999,
				"world_bounds": 100000.0,
				"hard_cap": 30.0,
				"max_speed": 18.0,
				"navigation_map": _server_world.get_nav_map_rid() if _server_world else RID(),
			}
			if not qn.peer_joined.is_connected(_on_peer_joined):
				qn.peer_joined.connect(_on_peer_joined)
			if not qn.peer_left.is_connected(_on_peer_left):
				qn.peer_left.connect(_on_peer_left)
			if not qn.custom_packet_received.is_connected(_on_custom_packet_received):
				qn.custom_packet_received.connect(_on_custom_packet_received)

			qn.host(DEFAULT_PORT, DEFAULT_SECRET, "*", DEFAULT_MAX_PLAYERS, config)
			print("[SERVER] QuanticNet host iniciado na porta %d (Bare-Metal UDP, max_speed=18.0, max_strikes=9999)." % DEFAULT_PORT)
	else:
		print("[SERVER] Modo Standalone ativo (fora da árvore de cena).")


func _on_peer_joined(peer_id: int) -> void:
	print("[SERVER] Novo cliente conectado com sucesso! (Peer ID: %d)" % peer_id)
	if _server_adapter and _server_adapter.has_method("register_peer"):
		_server_adapter.register_peer(peer_id)


func _on_peer_left(peer_id: int) -> void:
	print("[SERVER] Cliente desconectado. (Peer ID: %d)" % peer_id)
	_peer_states.erase(peer_id)
	if _server_adapter and _server_adapter.has_method("unregister_peer"):
		_server_adapter.unregister_peer(peer_id)


func _on_custom_packet_received(peer_id: int, ptype: int, data: PackedByteArray) -> void:
	if ptype == 101 and data.size() >= 25: # OP_CLIENT_STATE
		var seq = data.decode_u32(0)
		var px = data.decode_float(4)
		var py = data.decode_float(8)
		var pz = data.decode_float(12)
		var ry = data.decode_float(16)
		var _custom_flags = data.decode_u8(20)
		var dt = data.decode_float(21)
		var client_pos = Vector3(px, py, pz)
		var client_rot = Vector3(0.0, ry, 0.0)

		var now = Time.get_ticks_msec()

		if not _peer_states.has(peer_id):
			_peer_states[peer_id] = {
				"pos": client_pos,
				"rot": client_rot,
				"ts": now,
				"strikes": 0,
			}
			print("[SERVER VALIDATOR] Peer %d registrado na posicao inicial: (%.1f, %.1f, %.1f)" % [peer_id, px, py, pz])
			return

		var st = _peer_states[peer_id]
		var horiz_dist = Vector2(px, pz).distance_to(Vector2(st.pos.x, st.pos.z))
		var effective_dt = maxf(dt, 0.04)
		var h_speed = horiz_dist / effective_dt

		print("[SERVER STEP] Peer %d | pos: (%.1f, %.1f, %.1f) | dist: %.2fm | dt: %.3fs | h_speed: %.2f m/s (max: 18.0)" % [
			peer_id, px, py, pz, horiz_dist, dt, h_speed
		])

		if h_speed <= 18.0:
			st.pos = client_pos
			st.rot = client_rot
			st.ts = now
		else:
			# Violação de velocidade detectada (Speedhack x5 ou Teleporte)
			st.strikes += 1
			print("[SERVER REJECT & SNAPBACK] Peer %d | Motivo: speed_limit_exceeded (%.1f m/s > 18.0) | Snapback para: (%.1f, %.1f, %.1f) | Strikes: %d" % [
				peer_id, h_speed, st.pos.x, st.pos.y, st.pos.z, st.strikes
			])

			var snap_pkt = PackedByteArray()
			snap_pkt.resize(21)
			snap_pkt.encode_u32(0, seq)
			snap_pkt.encode_float(4, st.pos.x)
			snap_pkt.encode_float(8, st.pos.y)
			snap_pkt.encode_float(12, st.pos.z)
			snap_pkt.encode_float(16, st.rot.y)
			snap_pkt.encode_u8(20, 1) # Reason: 1 = SPEED_LIMIT

			var qn = get_node_or_null("/root/QuanticNet")
			if qn and qn.has_method("send_game_packet"):
				qn.send_game_packet(peer_id, 102, snap_pkt, false)


func get_server_world() -> RefCounted:
	return _server_world


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _server_world and _server_world.has_method("cleanup"):
			_server_world.cleanup()


func _exit_tree() -> void:
	if _server_world and _server_world.has_method("cleanup"):
		_server_world.cleanup()


func get_server_adapter() -> RefCounted:
	return _server_adapter
