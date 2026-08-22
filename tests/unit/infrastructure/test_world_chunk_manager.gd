## @file test_world_chunk_manager.gd
## @path res://tests/unit/infrastructure/test_world_chunk_manager.gd
##
## @description
## Testes unitários AAA para o nó de infraestrutura WorldChunkManager.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends GutTest

const WorldChunkManagerClass = preload("res://src/infrastructure/world_chunk_manager.gd")


func test_register_and_stream_chunk() -> void:
	# Arrange
	var manager = WorldChunkManagerClass.new("res://assets/maps", 1500.0)

	# Act
	var registered = manager.register_chunk("16_24")
	assert_true(registered, "Chunk 16_24 deve ser registrado com sucesso")

	# Simula avatar próximo do chunk 16_24
	manager.update_streaming(Vector3(-6552.0, -100.0, 19659.0))

	# Assert
	assert_eq(manager.get_active_chunk_count(), 1, "Chunk 16_24 deve estar carregado e ativo")

	# Act: Avatar move para longe
	manager.update_streaming(Vector3(50000.0, 0.0, 50000.0))

	# Assert
	assert_eq(manager.get_active_chunk_count(), 0, "Chunk 16_24 deve ter sido descarregado")

	# Cleanup
	manager.free()


func test_get_static_actors_in_radius() -> void:
	# Arrange: Registra e ativa o chunk 16_24
	var manager = WorldChunkManagerClass.new("res://assets/maps", 1500.0)
	manager.register_chunk("16_24")
	var origin_16_24 = Vector3(-6552.0, -100.0, 19659.0)
	manager.update_streaming(origin_16_24)

	# Act: Busca atores estáticos em raio de 500m
	var actors_near = manager.get_static_actors_in_radius(origin_16_24, 500.0)

	# Assert
	assert_gt(actors_near.size(), 0, "Deve encontrar atores estáticos carregados no raio de 500m")
	if not actors_near.is_empty():
		var first = actors_near[0]
		assert_true(first.has("actor_name"))
		assert_true(first.has("mesh_name"))
		assert_true(first.has("distance"))
		assert_true(first.has("classification_type"))

	# Act 2: Busca cilíndrica com grande desnível vertical de Y (+500m acima do solo)
	var high_altitude_origin = Vector3(origin_16_24.x, origin_16_24.y + 500.0, origin_16_24.z)
	var actors_high = manager.get_static_actors_in_radius(high_altitude_origin, 500.0)
	assert_eq(
		actors_high.size(),
		actors_near.size(),
		"Busca cilíndrica deve retornar os mesmos atores independente da cota Y"
	)

	# Cleanup
	manager.free()


func test_update_static_actor_transform_and_save_fix() -> void:
	# Arrange: Registra e ativa o chunk 16_24
	var manager = WorldChunkManagerClass.new("res://assets/maps", 1500.0)
	manager.register_chunk("16_24")
	var origin_16_24 = Vector3(-6552.0, -100.0, 19659.0)
	manager.update_streaming(origin_16_24)

	var actors = manager.get_static_actors_in_radius(origin_16_24, 500.0)
	if not actors.is_empty():
		var actor = actors[0]
		var actor_name = actor.get("actor_name", "")

		# Act 1: Obtém dados originais
		var raw = manager.get_raw_actor_data(actor_name)
		assert_false(raw.is_empty(), "Dados raw devem existir para o ator")

		# Act 2: Atualiza transform em tempo real
		var new_pos = Vector3(100.0, -250.0, 200.0)
		var new_rot = Vector3(0.0, 45.0, 0.0)
		var new_scale = Vector3(1.5, 1.5, 1.5)
		var update_res = manager.update_static_actor_transform(actor_name, new_pos, new_rot, new_scale)
		assert_true(update_res.get("found", false), "Atualização em tempo real deve ter sucesso")
		assert_eq(update_res.get("position"), new_pos)

		var target_chunk = update_res.get("chunk_name", "16_24")
		var orig_rot = raw.get("rotation_degrees", Vector3.ZERO)
		var orig_scale = raw.get("scale", Vector3.ONE)

		# Act 3: Salva o fix apenas com posição modificada
		var save_ok = manager.save_actor_fix(actor_name, new_pos, orig_rot, orig_scale)
		assert_true(save_ok, "save_actor_fix deve retornar true")

		# Assert Delta: Apenas location_meters deve ser salvo
		var loaded_fix = manager._resource_adapter.load_static_actors_fix_dict(target_chunk)
		assert_true(loaded_fix.get("actors", { }).has(actor_name), "Fix deve conter chave indexada por actor_name")
		var actor_fix = loaded_fix["actors"][actor_name]
		var xform_diff = actor_fix.get("transform", { })
		assert_true(xform_diff.has("location_meters"), "Deve conter location_meters alterado")
		assert_false(xform_diff.has("rotation_degrees"), "Não deve conter rotation_degrees se não foi alterado")
		assert_false(xform_diff.has("scale"), "Não deve conter scale se não foi alterado")

		# Cleanup do arquivo fix temporário criado
		var fix_file = "res://assets/maps/%s/chunk_static_actors_fix.json" % target_chunk
		var glob_f = ProjectSettings.globalize_path(fix_file)
		if FileAccess.file_exists(glob_f):
			DirAccess.remove_absolute(glob_f)

	# Cleanup
	manager.free()


func test_sample_world_altitude_in_manager() -> void:
	# Arrange
	var manager = WorldChunkManagerClass.new("res://assets/maps", 1500.0)
	manager.register_chunk("16_24")

	# Act: Amostra altitude dentro do chunk 16_24
	var origin_16_24 = Vector3(-7864.32, 0.0, 18350.08)
	var sample_res = manager.sample_world_altitude(origin_16_24.x, origin_16_24.z)

	# Assert
	assert_true(sample_res.get("found", false), "Deve encontrar o chunk 16_24 e retornar altitude")
	assert_eq(sample_res.get("chunk_name", ""), "16_24")
	assert_true(sample_res.has("altitude"))

	# Act 2: Coordenada fora do mundo
	var outside_res = manager.sample_world_altitude(999999.0, 999999.0)
	assert_false(outside_res.get("found", true), "Não deve encontrar altitude fora do mapa")

	# Cleanup
	manager.free()


func test_update_actor_collision_type_in_manager() -> void:
	# Arrange
	var manager = WorldChunkManagerClass.new("res://assets/maps", 1500.0)
	manager.register_chunk("16_24")
	var origin_16_24 = Vector3(-6552.0, -100.0, 19659.0)
	manager.update_streaming(origin_16_24)

	var actors = manager.get_static_actors_in_radius(origin_16_24, 500.0)
	if not actors.is_empty():
		var actor = actors[0]
		var actor_name = actor.get("actor_name", "")
		var chunk_name = actor.get("chunk_name", "16_24")

		# Act 1: Altera colisão para concave
		var res_concave = manager.update_actor_collision_type(actor_name, "concave", chunk_name)
		assert_true(res_concave, "update_actor_collision_type para concave deve retornar true")

		# Act 2: Altera colisão para pass_through
		var res_pass = manager.update_actor_collision_type(actor_name, "pass_through", chunk_name)
		assert_true(res_pass, "update_actor_collision_type para pass_through deve retornar true")

	# Cleanup
	manager.free()


func test_staging_buffer_and_batch_commit_in_manager() -> void:
	# Arrange
	var manager = WorldChunkManagerClass.new("res://assets/maps", 1500.0)
	manager.register_chunk("16_24")
	var origin_16_24 = Vector3(-6552.0, -100.0, 19659.0)
	manager.update_streaming(origin_16_24)

	var actors = manager.get_static_actors_in_radius(origin_16_24, 500.0)
	if not actors.is_empty():
		var actor = actors[0]
		var actor_name = actor.get("actor_name", "")
		var chunk_name = actor.get("chunk_name", "16_24")

		# Act 1: Modifica ator para popular o buffer
		var new_pos = Vector3(50.0, -120.0, 80.0)
		var new_rot = Vector3(0.0, 30.0, 0.0)
		var new_sc = Vector3(2.0, 2.0, 2.0)
		manager.update_static_actor_transform(actor_name, new_pos, new_rot, new_sc, chunk_name)

		# Assert 1: Ator deve ser dirty e summary deve contabilizar
		assert_true(manager.is_actor_dirty(actor_name, chunk_name), "Ator modificado deve estar marcado como dirty")
		var summary = manager.get_pending_fixes_summary()
		assert_eq(summary.get("total_actors"), 1, "Deve ter 1 ator pendente")
		assert_eq(summary.get("chunks_count"), 1, "Deve ter 1 chunk modificado")

		# Act 2: Salva tudo em lote
		var batch_res = manager.save_all_pending_actor_fixes()
		assert_true(batch_res.get("success", false))
		assert_eq(batch_res.get("saved_actors_count"), 1)
		assert_false(manager.is_actor_dirty(actor_name, chunk_name), "Buffer deve ser limpo após salvar em lote")

		# Cleanup do arquivo fix temporário
		var fix_file = "res://assets/maps/%s/chunk_static_actors_fix.json" % chunk_name
		var glob_f = ProjectSettings.globalize_path(fix_file)
		if FileAccess.file_exists(glob_f):
			DirAccess.remove_absolute(glob_f)

	# Cleanup
	manager.free()


func test_staging_buffer_discard_all() -> void:
	# Arrange
	var manager = WorldChunkManagerClass.new("res://assets/maps", 1500.0)
	manager.register_chunk("16_24")
	var origin_16_24 = Vector3(-6552.0, -100.0, 19659.0)
	manager.update_streaming(origin_16_24)

	var actors = manager.get_static_actors_in_radius(origin_16_24, 500.0)
	if not actors.is_empty():
		var actor = actors[0]
		var actor_name = actor.get("actor_name", "")
		var chunk_name = actor.get("chunk_name", "16_24")

		# Act: Modifica ator e depois descarta
		manager.update_static_actor_transform(actor_name, Vector3(999.0, 999.0, 999.0), Vector3.ZERO, Vector3.ONE, chunk_name)
		assert_true(manager.is_actor_dirty(actor_name, chunk_name))

		var discarded = manager.discard_all_pending_actor_fixes()
		assert_eq(discarded, 1, "Deve descartar 1 ator")
		assert_false(manager.is_actor_dirty(actor_name, chunk_name), "Buffer deve ficar vazio após descarte")

	# Cleanup
	manager.free()



