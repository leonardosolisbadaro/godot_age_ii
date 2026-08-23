## @file test_debug_window.gd
## @path res://tests/debug/test_debug_window.gd
##
## @description
## Testes unitarios GUT AAA do DebugWindow.
## Valida ciclo de vida (open, close, toggle), emissao de sinais e estrutura de conteudo.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
extends GutTest

const DebugWindowClass = preload("res://src/debug/debug_window.gd")


func test_initialization_defaults() -> void:
	# Arrange & Act
	var window = DebugWindowClass.new("Janela Teste", 300.0)
	add_child_autofree(window)

	# Assert
	assert_eq(window.window_title, "Janela Teste", "Titulo deve ser inicializado corretamente.")
	assert_false(window.is_open(), "Janela deve iniciar fechada por padrao.")
	assert_not_null(window.get_content_vbox(), "ContentVBox deve existir para insercao de widgets.")


func test_open_close_and_toggle() -> void:
	# Arrange
	var window = DebugWindowClass.new("Janela Teste")
	add_child_autofree(window)
	watch_signals(window)

	# Act - Open
	window.open_window()

	# Assert - Open
	assert_true(window.is_open(), "Janela deve estar aberta.")
	assert_signal_emitted(window, "window_opened", "Sinal window_opened deve ser emitido.")

	# Act - Close
	window.close_window()

	# Assert - Close
	assert_false(window.is_open(), "Janela deve estar fechada.")
	assert_signal_emitted(window, "window_closed", "Sinal window_closed deve ser emitido.")

	# Act - Toggle
	window.toggle_window()

	# Assert - Toggle
	assert_true(window.is_open(), "Janela deve alternar para aberta.")


func test_add_content_to_vbox() -> void:
	# Arrange
	var window = DebugWindowClass.new("Janela Conteudo")
	add_child_autofree(window)

	var label = Label.new()
	label.name = "TestLabel"

	# Act
	window.get_content_vbox().add_child(label)

	# Assert
	assert_true(
		window.has_node("WindowMainVBox/ContentMargin/ContentVBox/TestLabel"),
		"Conteudo deve estar aninhado no ContentVBox.",
	)
