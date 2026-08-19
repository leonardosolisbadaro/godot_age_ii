## @file test_server_movement_validator.gd
## @path res://tests/unit/domain/test_server_movement_validator.gd
##
## @description
## Testes unitários AAA para a entidade de domínio ServerMovementValidator.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends GutTest

const ServerMovementValidatorClass = preload("res://src/domain/server_movement_validator.gd")
const HeightfieldSamplerClass = preload("res://src/domain/heightfield_sampler.gd")


func test_valid_step_within_speed_limit() -> void:
	# Arrange: Velocidade 6.0 m/s em delta 0.05s -> Máx ~0.39m (com tolerância 1.3)
	var validator = ServerMovementValidatorClass.new()
	var from_p = Vector3(0.0, 0.0, 0.0)
	var to_p = Vector3(0.2, 0.0, 0.1) # Distância ~0.223m

	# Act
	var res = validator.validate_step(from_p, to_p, null, null, 0.05, 6.0)

	# Assert
	assert_true(res["valid"], "Movimento legítimo dentro da velocidade permitida")
	assert_eq(res["reason"], "OK")
	assert_almost_eq(res["corrected_pos"], to_p, Vector3(0.001, 0.001, 0.001))


func test_teleport_or_speedhack_rejection() -> void:
	# Arrange: Tentativa de mover 10 metros em 0.05s
	var validator = ServerMovementValidatorClass.new()
	var from_p = Vector3(0.0, 0.0, 0.0)
	var to_p = Vector3(10.0, 0.0, 0.0)

	# Act
	var res = validator.validate_step(from_p, to_p, null, null, 0.05, 6.0)

	# Assert
	assert_false(res["valid"], "Movimento excessivo deve ser rejeitado")
	assert_eq(res["reason"], "SPEED_LIMIT_EXCEEDED")
	assert_almost_eq(res["corrected_pos"], from_p, Vector3(0.001, 0.001, 0.001), "Deve retornar à posição anterior")


func test_steep_mountain_slope_rejection() -> void:
	# Arrange: Terreno com declive vertical muito íngreme (ex: parede de 20m de altura em 2m de base)
	var heights = PackedFloat32Array([
		0.0, 50.0,
		0.0, 50.0
	])
	var sampler = HeightfieldSamplerClass.new(
		heights,
		2, 2,
		2.0, 2.0,
		Vector3.ZERO,
		2.0, 2.0
	)
	var validator = ServerMovementValidatorClass.new()
	var from_p = Vector3(0.0, 0.0, 0.0)
	var to_p = Vector3(0.1, 0.0, 0.0)

	# Act: Limite de declive 1.0 (45 graus), rampa tem declive > 20.0
	var res = validator.validate_step(from_p, to_p, sampler, null, 0.05, 6.0, 1.0)

	# Assert
	assert_false(res["valid"], "Subida de montanha com declive excessivo deve ser bloqueada")
	assert_eq(res["reason"], "SLOPE_TOO_STEEP")
