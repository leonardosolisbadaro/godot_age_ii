## @file quantic_net_server_adapter.gd
## @path res://src/adapters/quantic_net_server_adapter.gd
##
## @description
## Adaptador de interface que traduz eventos e dados do plugin de rede QuanticNet
## para o domínio autoritativo do servidor de jogo de forma totalmente agnóstica.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends RefCounted

var _active_peers: Dictionary = {} # { peer_id: { "position": Vector3, "rotation": Vector3, "last_seq": int } }


func register_peer(peer_id: int, initial_pos: Vector3, initial_rot: Vector3 = Vector3.ZERO) -> void:
	_active_peers[peer_id] = {
		"position": initial_pos,
		"rotation": initial_rot,
		"last_seq": 0
	}


func unregister_peer(peer_id: int) -> void:
	_active_peers.erase(peer_id)


func has_peer(peer_id: int) -> bool:
	return _active_peers.has(peer_id)


func get_peer_state(peer_id: int) -> Dictionary:
	return _active_peers.get(peer_id, {})


func update_peer_state(peer_id: int, pos: Vector3, rot: Vector3, seq: int = 0) -> void:
	if _active_peers.has(peer_id):
		_active_peers[peer_id]["position"] = pos
		_active_peers[peer_id]["rotation"] = rot
		_active_peers[peer_id]["last_seq"] = seq


func get_active_peers() -> Dictionary:
	return _active_peers.duplicate(true)
