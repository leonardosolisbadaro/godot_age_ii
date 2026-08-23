## @file test_server_world_manager.gd
## @path res://tests/unit/infrastructure/test_server_world_manager.gd
##
## @description
## Testes unitários AAA para ServerWorldManager.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends GutTest

const ServerWorldManagerClass = preload("res://src/infrastructure/server_world_manager.gd")


func test_load_server_chunk_and_validate_physics() -> void:
	# Arrange
	var server_world = ServerWorldManagerClass.new("res://assets/maps")

	# Act
	var loaded = server_world.load_server_chunk("16_24")

	# Assert
	assert_true(loaded, "Chunk 16_24 deve ser carregado no servidor")
	assert_has(server_world.get_loaded_chunks(), "16_24")

	# Amostragem de altitude no centro do chunk
	var alt_res = server_world.get_altitude_at(-7864.0, 18350.0)
	assert_true(alt_res["found"])
	assert_eq(alt_res["chunk_name"], "16_24")

	# Validação de movimento legítimo
	var move_res = server_world.validate_movement(
		Vector3(-7864.0, alt_res["altitude"], 18350.0),
		Vector3(-7863.8, alt_res["altitude"], 18350.1),
		0.05,
		6.0
	)
	assert_true(move_res["valid"])

	# Cleanup
	server_world.cleanup()
