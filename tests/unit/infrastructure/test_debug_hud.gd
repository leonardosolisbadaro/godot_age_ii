## @file test_debug_hud.gd
## @path res://tests/unit/infrastructure/test_debug_hud.gd
##
## @description
## Testes unitários AAA para o nó de interface DebugHUD (Mini-IDE in-game).
##
## @created 2026-08-22
## @updated 2026-08-22
##
## @author Leonardo S. Badaró
extends GutTest

const DebugHUDClass = preload("res://src/infrastructure/debug_hud.gd")


func test_debug_hud_initialization() -> void:
	# Arrange
	var hud = DebugHUDClass.new()
	add_child_autofree(hud)

	# Act
	# O _ready() é chamado automaticamente ao adicionar à cena

	# Assert
	assert_not_null(hud._top_bar, "Top bar deve ser inicializada")
	assert_not_null(hud._outliner_window, "Janela de Outliner deve ser inicializada")
	assert_not_null(hud._inspector_window, "Janela de Inspetor deve ser inicializada")
	assert_not_null(hud._water_editor_window, "Janela de Volumes de Agua deve ser inicializada")
	assert_not_null(hud._teleports_window, "Janela de Teleportes deve ser inicializada")
	assert_not_null(hud._telemetry_window, "Janela de Telemetria deve ser inicializada")

	assert_false(hud._outliner_window.visible, "Outliner deve iniciar oculto")
	assert_false(hud._inspector_window.visible, "Inspetor deve iniciar oculto")
	assert_false(hud._water_editor_window.visible, "Volumes de Agua deve iniciar oculto")
	assert_false(hud._teleports_window.visible, "Teleportes deve iniciar oculto")
	assert_false(hud._telemetry_window.visible, "Telemetria deve iniciar oculta")


func test_debug_hud_file_menu_only_exit() -> void:
	# Arrange
	var hud = DebugHUDClass.new()
	add_child_autofree(hud)

	# Act
	var popup = hud._menu_file.get_popup()

	# Assert: Menu Arquivo deve conter estritamente apenas a opcao de Sair (id 99)
	assert_eq(popup.item_count, 1, "Menu Arquivo deve conter exatamente 1 item")
	assert_eq(popup.get_item_id(0), 99, "O unico item deve ter o ID 99 (Sair)")
	assert_true(popup.get_item_text(0).contains("Sair"), "Texto do item deve indicar Sair")


func test_debug_hud_cascade_close() -> void:
	# Arrange
	var hud = DebugHUDClass.new()
	add_child_autofree(hud)
	hud._outliner_window.visible = true
	hud._water_editor_window.visible = true
	hud._inspector_window.visible = true

	# Act 1: Fecha a janela do topo (Inspector tem maior prioridade)
	var closed_first = hud.close_topmost_window()

	# Assert 1
	assert_true(closed_first, "Deve fechar a janela mais interna")
	assert_false(hud._inspector_window.visible, "Inspetor deve ser fechado")
	assert_true(hud._water_editor_window.visible, "Janela de agua deve permanecer aberta")

	# Act 2: Fecha a próxima janela (Water Editor)
	var closed_second = hud.close_topmost_window()

	# Assert 2
	assert_true(closed_second, "Deve fechar o editor de agua")
	assert_false(hud._water_editor_window.visible, "Editor de agua deve ser fechado")
	assert_true(hud._outliner_window.visible, "Outliner deve permanecer aberto")

	# Act 3: Fecha o outliner
	var closed_third = hud.close_topmost_window()
	assert_true(closed_third, "Deve fechar o outliner")
	assert_false(hud._outliner_window.visible, "Outliner agora deve ser fechado")

	# Act 4: Nenhuma janela restante
	var closed_fourth = hud.close_topmost_window()
	assert_false(closed_fourth, "Não deve haver mais janelas a fechar")


func test_debug_hud_telemetry_update() -> void:
	# Arrange
	var hud = DebugHUDClass.new()
	add_child_autofree(hud)
	hud._telemetry_window.visible = true
	var test_pos = Vector3(100.5, -220.3, 300.8)
	var test_chunk = "17_25"

	# Act
	hud.update_telemetry(test_pos, test_chunk, true, -225.0, true)

	# Assert
	assert_true(hud._label_quick_badge.text.contains("17_25"), "Quick badge deve conter nome do chunk")
	assert_true(hud._label_quick_badge.text.contains("100.5"), "Quick badge deve conter coordenada X")
	assert_true(hud._label_quick_badge.text.contains("Pendencias: 0"), "Quick badge deve conter pendencias")
	assert_false(hud._label_quick_badge.text.contains("[WIREFRAME]"), "Quick badge nao deve conter wireframe")
	assert_true(hud._label_telemetry_body.text.contains("RENDERIZACAO & GPU"), "Deve conter secao de renderizacao")
	assert_true(hud._label_telemetry_body.text.contains("Draw Calls:"), "Deve conter contagem de draw calls")
	assert_true(hud._label_telemetry_body.text.contains("MUNDO & STREAMING"), "Deve conter secao de mundo e streaming")
	assert_true(hud._label_telemetry_body.text.contains("ENGINE & FISICA"), "Deve conter secao de engine e fisica")
	assert_true(hud._label_telemetry_body.text.contains("REDE (QuanticNet)"), "Deve conter secao de rede")
	assert_true(hud._label_telemetry_body.text.contains("[WIREFRAME]"), "Corpo de telemetria deve indicar wireframe")
	assert_true(hud._label_telemetry_body.text.contains("[F2] Telemetria"), "Deve listar atalho essencial F2")
	assert_false(hud._label_telemetry_body.text.contains("[F5]"), "Nao deve listar atalhos descontinuados como F5")
	assert_false(hud._label_telemetry_body.text.contains("[F12]"), "Nao deve listar atalhos descontinuados como F12")


func test_debug_hud_water_editor_population_and_events() -> void:
	# Arrange
	var hud = DebugHUDClass.new()
	add_child_autofree(hud)
	watch_signals(hud)

	var dummy_water_data = {
		"water_volumes": {
			"WaterVolume0": {
				"name": "WaterVolume0",
				"water_plane_height_m": -320.0,
				"surface_y_m": -320.0,
				"center_m": [100.0, 200.0],
				"size_m": [2621.44, 2621.44],
				"ocean_extension": 500.0,
				"enabled": true
			}
		}
	}

	# Act 1: Popula volumes de água do chunk 17_25
	hud.populate_water_volumes("17_25", dummy_water_data)

	# Assert 1: Campos devem ser populados com os dados do volume 0
	assert_eq(hud._option_water_volume.item_count, 1, "Deve carregar 1 volume de agua")
	assert_almost_eq(hud._spin_water_y.value, -320.0, 0.1, "Altitude Y deve ser -320.0m")
	assert_almost_eq(hud._spin_water_center_x.value, 100.0, 0.1, "Centro X deve ser 100.0m")
	assert_almost_eq(hud._spin_water_center_z.value, 200.0, 0.1, "Centro Z deve ser 200.0m")
	assert_almost_eq(hud._spin_water_ocean_ext.value, 500.0, 0.1, "Extensao oceano deve ser 500.0m")

	# Act 2: Altera altitude da água
	hud._spin_water_y.value = -315.0
	hud._on_water_field_changed(0.0)

	# Assert 2: Sinal water_volume_transform_applied deve ser emitido
	assert_signal_emitted(hud, "water_volume_transform_applied", "Deve emitir transform_applied em tempo real")

	# Act 3: Clica em salvar fix
	hud._on_btn_water_save_pressed()

	# Assert 3: Sinal water_volume_fix_saved deve ser emitido
	assert_signal_emitted(hud, "water_volume_fix_saved", "Deve emitir water_volume_fix_saved ao salvar")

	# Act 4: Clica em resetar original
	hud._on_btn_water_reset_pressed()

	# Assert 4: Sinal water_volume_reset_requested deve ser emitido
	assert_signal_emitted(hud, "water_volume_reset_requested", "Deve emitir water_volume_reset_requested ao resetar")


func test_debug_hud_actor_filtering() -> void:
	# Arrange
	var hud = DebugHUDClass.new()
	add_child_autofree(hud)
	var dummy_actors: Array[Dictionary] = [
		{
			"actor_name": "Tree_01",
			"mesh_name": "speaking_tree_s",
			"package_name": "T_Trees",
			"classification_type": "tree_trunk",
			"distance": 15.0,
			"chunk_name": "17_25"
		},
		{
			"actor_name": "House_01",
			"mesh_name": "talking_house_a",
			"package_name": "T_Buildings",
			"classification_type": "concave",
			"distance": 25.0,
			"chunk_name": "17_25"
		}
	]

	# Act 1: Atualiza atores com filtro padrao ("all")
	hud.update_nearby_actors(dummy_actors, 40.0)

	# Assert 1
	assert_eq(hud._filtered_actors.size(), 2, "Filtro 'all' deve listar todos os atores")

	# Act 2: Aplica filtro "trees"
	hud._set_active_filter("trees")

	# Assert 2
	assert_eq(hud._filtered_actors.size(), 1, "Filtro 'trees' deve retornar apenas a arvore")
	assert_eq(hud._filtered_actors[0].get("actor_name"), "Tree_01", "Ator retornado deve ser Tree_01")


func test_debug_hud_dirty_actor_feedback_and_counter() -> void:
	# Arrange
	var hud = DebugHUDClass.new()
	add_child_autofree(hud)
	var dummy_actors: Array[Dictionary] = [
		{
			"actor_name": "Tree_01",
			"mesh_name": "speaking_tree_s",
			"package_name": "T_Trees",
			"classification_type": "tree_trunk",
			"distance": 15.0,
			"chunk_name": "17_25"
		},
		{
			"actor_name": "House_01",
			"mesh_name": "talking_house_a",
			"package_name": "T_Buildings",
			"classification_type": "concave",
			"distance": 25.0,
			"chunk_name": "17_25"
		}
	]
	hud.update_nearby_actors(dummy_actors, 40.0)

	# Act 1: Marca Tree_01 como dirty
	hud.update_pending_summary({
		"total_actors": 1,
		"chunks_count": 1,
		"chunks": ["17_25"],
		"dirty_set": { "Tree_01": true }
	})

	# Assert 1: Tree_01 deve ter prefixo '*' e o rodape deve indicar 1 alterado nao salvo
	assert_true(hud._item_list.get_item_text(0).begins_with("* "), "Ator dirty deve ter prefixo '* '")
	assert_false(hud._item_list.get_item_text(1).begins_with("* "), "Ator limpo nao deve ter prefixo '* '")
	assert_true(hud._label_outliner_footer.text.contains("1 alterado(s) nao salvo(s)"), "Rodape deve exibir contagem dirty")

	# Act 2: Salva / limpa todas as alteracoes
	hud.update_pending_summary({
		"total_actors": 0,
		"chunks_count": 0,
		"chunks": [],
		"dirty_set": {}
	})

	# Assert 2: Nenhum ator deve ter prefixo '*'
	assert_false(hud._item_list.get_item_text(0).begins_with("* "), "Prefixo '* ' deve ser removido apos salvar")
	assert_false(hud._label_outliner_footer.text.contains("alterado"), "Rodape nao deve exibir pendencias quando limpo")


func test_debug_hud_set_and_get_editor_values() -> void:
	# Arrange
	var hud = DebugHUDClass.new()
	add_child_autofree(hud)
	var target_pos = Vector3(12.34, -56.78, 90.12)
	var target_rot = Vector3(10.0, 45.0, 90.0)
	var target_sc = Vector3(1.5, 1.5, 1.5)

	# Act
	hud.set_editor_values(target_pos, target_rot, target_sc, "Status OK")

	# Assert
	assert_almost_eq(hud.get_current_position().x, target_pos.x, 0.01, "Posicao X deve ser precisa")
	assert_almost_eq(hud.get_current_rotation().y, target_rot.y, 0.01, "Rotacao Y (Yaw) deve ser precisa")
	assert_almost_eq(hud.get_current_scale().x, target_sc.x, 0.01, "Escala X deve ser precisa")
	assert_eq(hud._label_editor_status.text, "Status OK", "Mensagem de status deve ser atualizada")
