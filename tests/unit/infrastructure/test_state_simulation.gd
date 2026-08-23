## @file test_state_simulation.gd
## @path res://tests/unit/infrastructure/test_state_simulation.gd
##
## @description
## Testes unitários AAA para Simulação State-Based Autoritativa e Snapbacks.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
extends GutTest

const PlayerAvatarClass = preload("res://src/infrastructure/player_avatar.gd")
const ServerMovementValidatorClass = preload("res://src/domain/server_movement_validator.gd")
const ServerWorldManagerClass = preload("res://src/infrastructure/server_world_manager.gd")


func test_player_avatar_reconcile_server_state() -> void:
	# Arrange
	var avatar = PlayerAvatarClass.new()
	avatar.position = Vector3(100.0, 50.0, 100.0)
	avatar.velocity = Vector3(50.0, 0.0, 50.0)
	add_child_autofree(avatar)

	var authoritative_pos = Vector3(10.0, 2.0, 10.0)
	var authoritative_rot = Vector3.ZERO

	# Act
	avatar.reconcile_server_state(authoritative_pos, authoritative_rot)

	# Assert
	assert_eq(avatar.global_position, authoritative_pos, "Avatar deve reconciliar posicao exata enviada pelo servidor")
	assert_eq(avatar.velocity, Vector3.ZERO, "Velocidade deve ser zerada no snapback")


func test_server_authoritative_movement_validator_rejects_speedhack() -> void:
	# Arrange
	var validator = ServerMovementValidatorClass.new()
	var start_pos = Vector3(0.0, 0.0, 0.0)
	var delta_time = 0.1

	# Act 1: Movimento legítimo a 15 m/s (1.5m em 0.1s)
	var legitimate_pos = Vector3(1.5, 0.0, 0.0)
	var leg_res = validator.validate_step(start_pos, legitimate_pos, null, null, null, delta_time, 18.0)

	# Assert 1
	assert_true(leg_res.valid, "Passo legitimo dentro de 18 m/s deve ser aceito")

	# Act 2: Speedhack x5 (8.0m em 0.1s = 80 m/s)
	var speedhack_pos = Vector3(8.0, 0.0, 0.0)
	var hack_res = validator.validate_step(legitimate_pos, speedhack_pos, null, null, null, delta_time, 18.0)

	# Assert 2
	assert_false(hack_res.valid, "Speedhack de 80 m/s deve ser rejeitado")
	assert_eq(hack_res.reason, "SPEED_LIMIT_EXCEEDED", "Motivo deve ser SPEED_LIMIT_EXCEEDED")
	assert_eq(hack_res.corrected_pos, legitimate_pos, "Posicao corrigida deve ser a ultima valida")


func test_server_world_manager_navmesh_and_speed_validation() -> void:
	# Arrange
	var server_world = ServerWorldManagerClass.new("res://assets/maps")
	var ok = server_world.load_server_chunk("17_25")
	assert_true(ok, "Chunk 17_25 deve carregar com sucesso")

	# Act
	var navmesh = server_world.get_chunk_navmesh("17_25")
	var map_rid = server_world.get_nav_map_rid()

	# Assert
	assert_not_null(navmesh, "Navmesh do chunk 17_25 deve estar carregada")
	assert_true(map_rid.is_valid(), "RID do mapa deve ser valido")
	assert_gt(navmesh.get_polygon_count(), 0, "Navmesh deve possuir poligonos")

	# Cleanup
	server_world.cleanup()
