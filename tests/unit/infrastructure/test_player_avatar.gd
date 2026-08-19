## @file test_player_avatar.gd
## @path res://tests/unit/infrastructure/test_player_avatar.gd
##
## @description
## Testes unitários AAA para o nó de infraestrutura PlayerAvatar.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends GutTest

const PlayerAvatarClass = preload("res://src/infrastructure/player_avatar.gd")


func test_player_avatar_instantiation_and_nodes() -> void:
	# Arrange
	var avatar = PlayerAvatarClass.new()

	# Act
	avatar._ready()

	# Assert
	assert_not_null(avatar.get_node_or_null("AvatarCollisionShape"))
	assert_not_null(avatar.get_node_or_null("AvatarMesh"))
	assert_not_null(avatar.get_node_or_null("CameraPivot"))
	assert_not_null(avatar.get_node_or_null("CameraPivot/SpringArm"))
	assert_not_null(avatar.get_node_or_null("CameraPivot/SpringArm/ThirdPersonCamera"))

	# Cleanup
	avatar.free()
