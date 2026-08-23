## @file test_graphics_telemetry_panel.gd
## @path res://tests/debug/test_graphics_telemetry_panel.gd
##
## @description
## Testes unitarios GUT AAA do GraphicsTelemetryPanel.
## Valida leitura de metricas da engine (FPS, Frame Time, VRAM), atualizacao visual e ciclo de vida.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
extends GutTest

const GraphicsTelemetryPanelClass = preload("res://src/debug/panels/graphics_telemetry_panel.gd")


func test_initialization_and_metrics_sampling() -> void:
	# Arrange & Act
	var panel = GraphicsTelemetryPanelClass.new()
	add_child_autofree(panel)

	# Assert
	assert_not_null(
		panel.get_node("WindowMainVBox/ContentMargin/ContentVBox/FpsLabel"),
		"FpsLabel deve existir.",
	)
	assert_not_null(
		panel.get_node("WindowMainVBox/ContentMargin/ContentVBox/FrameTimeLabel"),
		"FrameTimeLabel deve existir.",
	)
	assert_not_null(
		panel.get_node("WindowMainVBox/ContentMargin/ContentVBox/VramLabel"),
		"VramLabel deve existir.",
	)


func test_periodic_update_execution() -> void:
	# Arrange
	var panel = GraphicsTelemetryPanelClass.new()
	add_child_autofree(panel)

	# Act
	panel._process(0.3)

	# Assert
	assert_gte(panel.get_current_fps(), 0.0, "FPS deve ser amostrado sem erros.")
	assert_gte(panel.get_current_vram_mb(), 0.0, "VRAM deve ser consultada sem erros.")
