## @file test_player_avatar_view.gd
## @path res://tests/client/test_player_avatar_view.gd
##
## @description
## Testes unitarios GUT AAA do nó de apresentacao PlayerAvatarView.
## Valida instanciacao de componentes visuais, camera em 3a pessoa e metodo de teleporte.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
extends GutTest

const PlayerAvatarViewClass = preload("res://src/client/infrastructure/player_avatar_view.gd")


func test_local_avatar_initialization() -> void:
	# Arrange & Act
	var avatar = PlayerAvatarViewClass.new(true, 1)
	add_child_autofree(avatar)

	# Assert
	assert_true(avatar.is_local, "Avatar deve ser marcado como local.")
	assert_eq(avatar.peer_id, 1, "Peer ID deve ser 1.")
	assert_not_null(avatar.stats, "Stats devem ser inicializados.")
	assert_not_null(avatar.current_state, "Current state deve ser inicializado.")


func test_remote_avatar_initialization() -> void:
	# Arrange & Act
	var avatar = PlayerAvatarViewClass.new(false, 2)
	add_child_autofree(avatar)

	# Assert
	assert_false(avatar.is_local, "Avatar remoto nao deve ser local.")
	assert_eq(avatar.peer_id, 2, "Peer ID deve ser 2.")


func test_teleport_updates_position_and_state() -> void:
	# Arrange
	var avatar = PlayerAvatarViewClass.new(true, 1)
	add_child_autofree(avatar)
	var target_pos = Vector3(-5420.0, -180.0, 20725.0)

	# Act
	avatar.teleport(target_pos)

	# Assert
	assert_almost_eq(
		avatar.global_position.x,
		target_pos.x,
		0.01,
		"global_position.x deve ser atualizada no teleporte.",
	)
	assert_almost_eq(
		avatar.global_position.z,
		target_pos.z,
		0.01,
		"global_position.z deve ser atualizada no teleporte.",
	)
	assert_almost_eq(
		avatar.current_state.position.x,
		target_pos.x,
		0.01,
		"current_state.position.x deve refletir o teleporte.",
	)
	assert_almost_eq(
		avatar.current_state.position.z,
		target_pos.z,
		0.01,
		"current_state.position.z deve refletir o teleporte.",
	)
	assert_gt(
		avatar.global_position.y,
		-500.0,
		"global_position.y deve estar assentada no relevo do terreno.",
	)
