## @file test_hack_injector.gd
## @path res://tests/unit/infrastructure/test_hack_injector.gd
##
## @description
## Testes unitários AAA para a Janela de Injeção de Hacks (Test Harness)
## e modificadores de física do PlayerAvatar.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
extends GutTest

const DebugHUDClass = preload("res://src/infrastructure/debug_hud.gd")
const PlayerAvatarClass = preload("res://src/infrastructure/player_avatar.gd")


func test_hack_injector_window_lifecycle_and_signals() -> void:
	# Arrange
	var hud = DebugHUDClass.new()
	add_child_autofree(hud)
	watch_signals(hud)

	# Assert inicial
	assert_not_null(hud._hack_injector_window, "Janela de hacks deve ser instanciada")
	assert_false(hud._hack_injector_window.visible, "Janela de hacks deve iniciar invisivel")

	# Act 1: Alterna visibilidade
	hud.toggle_hack_injector_window()
	assert_true(hud._hack_injector_window.visible, "Janela de hacks deve ficar visivel apos toggle")

	# Act 2: Clica nos botões de injeção de hacks
	hud._btn_hack_speed.emit_signal("pressed")
	hud._btn_hack_teleport.emit_signal("pressed")
	hud._btn_hack_noclip.emit_signal("pressed")
	hud._btn_hack_fly.emit_signal("pressed")

	# Assert 2: Sinais emitidos corretamente
	assert_signal_emitted(hud, "speedhack_toggled", "Deve emitir sinal de speedhack")
	assert_signal_emitted(hud, "force_teleport_requested", "Deve emitir sinal de teleporte forcado")
	assert_signal_emitted(hud, "noclip_toggled", "Deve emitir sinal de noclip")
	assert_signal_emitted(hud, "flyhack_requested", "Deve emitir sinal de flyhack")


func test_snapback_counter_increment_and_cascade_close() -> void:
	# Arrange
	var hud = DebugHUDClass.new()
	add_child_autofree(hud)
	hud.toggle_hack_injector_window()

	# Act 1: Incrementa snapback
	hud.increment_snapback_counter("Violacao de Velocidade")

	# Assert 1
	assert_eq(hud._snapback_count, 1, "Contador de snapbacks deve ser 1")
	assert_true(hud._label_snapback_stats.text.contains("1"), "Texto deve exibir contagem 1")
	assert_true(hud._label_snapback_stats.text.contains("Violacao de Velocidade"), "Texto deve exibir motivo")

	# Act 2: Fechamento em cascata (ESC)
	var closed = hud.close_topmost_window()

	# Assert 2
	assert_true(closed, "Fechamento em cascata deve fechar a janela de hacks")
	assert_false(hud._hack_injector_window.visible, "Janela de hacks deve ficar invisivel")


func test_player_avatar_hack_modifiers() -> void:
	# Arrange
	var avatar = PlayerAvatarClass.new()
	avatar.position = Vector3(0.0, 10.0, 0.0)
	add_child_autofree(avatar)

	# Act 1: Speedhack
	avatar.set_speedhack(true, 5.0)
	assert_eq(avatar.speed_hack_multiplier, 5.0, "Multiplicador de velocidade deve ser 5.0")
	avatar.set_speedhack(false)
	assert_eq(avatar.speed_hack_multiplier, 1.0, "Multiplicador deve resetar para 1.0")

	# Act 2: No-Clip
	avatar.set_noclip(true)
	assert_true(avatar.is_noclip, "No-clip deve estar ativo")
	assert_true(avatar._col_shape.disabled, "Shape de colisao deve ser desativado no noclip")
	avatar.set_noclip(false)
	assert_false(avatar.is_noclip, "No-clip deve ser desativado")
	assert_false(avatar._col_shape.disabled, "Shape de colisao deve ser reativado")

	# Act 3: Teleporte Forçado
	var initial_pos = avatar.global_position
	avatar.apply_forced_teleport(30.0)
	assert_ne(avatar.global_position, initial_pos, "Posicao deve ter se deslocado apos teleporte")

	# Act 4: Flyhack
	var y_before = avatar.global_position.y
	avatar.apply_flyhack(15.0)
	assert_almost_eq(avatar.global_position.y, y_before + 15.0, 0.1, "Altitude deve subir 15m apos flyhack")
