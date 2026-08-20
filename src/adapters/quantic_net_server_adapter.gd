## @file quantic_net_server_adapter.gd
## @path res://src/adapters/quantic_net_server_adapter.gd
##
## @description
## Adaptador de interface para gerenciamento de sessões de jogadores conectados
## e abstração da API de rede QuanticNet.
##
## @created 2026-08-19
## @updated 2026-08-20
##
## @author Leonardo S. Badaró
extends RefCounted

var _peers: Dictionary = { } # { peer_id: { "position": Vector3, "rotation": Vector3, "last_seq": int, ... } }


func register_peer(peer_id: int, spawn_pos: Vector3 = Vector3.ZERO) -> void:
	if not _peers.has(peer_id):
		_peers[peer_id] = {
			"peer_id": peer_id,
			"position": spawn_pos,
			"rotation": Vector3.ZERO,
			"last_seq": 0,
			"connected_at": Time.get_ticks_msec(),
		}


func unregister_peer(peer_id: int) -> void:
	_peers.erase(peer_id)


func has_peer(peer_id: int) -> bool:
	return _peers.has(peer_id)


func is_peer_registered(peer_id: int) -> bool:
	return _peers.has(peer_id)


func get_peer_count() -> int:
	return _peers.size()


func update_peer_state(
	peer_id: int,
	pos_or_dict: Variant,
	rot: Vector3 = Vector3.ZERO,
	seq: int = 0,
) -> void:
	if not _peers.has(peer_id):
		return

	if pos_or_dict is Dictionary:
		for k in pos_or_dict.keys():
			_peers[peer_id][k] = pos_or_dict[k]
	elif pos_or_dict is Vector3:
		_peers[peer_id]["position"] = pos_or_dict
		_peers[peer_id]["rotation"] = rot
		_peers[peer_id]["last_seq"] = seq


func get_peer_state(peer_id: int) -> Dictionary:
	return _peers.get(peer_id, { })
