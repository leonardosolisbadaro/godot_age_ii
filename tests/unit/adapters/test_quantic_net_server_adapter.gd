## @file test_quantic_net_server_adapter.gd
## @path res://tests/unit/adapters/test_quantic_net_server_adapter.gd
##
## @description
## Testes unitários AAA para QuanticNetServerAdapter.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends GutTest

const QuanticNetServerAdapterClass = preload("res://src/adapters/quantic_net_server_adapter.gd")


func test_register_and_unregister_peer() -> void:
	# Arrange
	var adapter = QuanticNetServerAdapterClass.new()
	var spawn_pos = Vector3(100.0, 20.0, -50.0)

	# Act
	adapter.register_peer(42, spawn_pos)

	# Assert
	assert_true(adapter.has_peer(42))
	var state = adapter.get_peer_state(42)
	assert_eq(state.get("position", Vector3.ZERO), spawn_pos)

	# Act: Unregister
	adapter.unregister_peer(42)
	assert_false(adapter.has_peer(42))


func test_update_peer_state() -> void:
	# Arrange
	var adapter = QuanticNetServerAdapterClass.new()
	adapter.register_peer(10, Vector3.ZERO)

	# Act
	adapter.update_peer_state(10, Vector3(15.0, 2.0, 30.0), Vector3(0.0, 1.57, 0.0), 123)

	# Assert
	var state = adapter.get_peer_state(10)
	assert_eq(state.get("position", Vector3.ZERO), Vector3(15.0, 2.0, 30.0))
	assert_eq(state.get("last_seq", 0), 123)
