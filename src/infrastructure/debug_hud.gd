## @file debug_hud.gd
## @path res://src/infrastructure/debug_hud.gd
##
## @description
## Camada de interface de depuração (CanvasLayer) exibindo telemetria em tempo real
## de coordenadas mundiais, chunk ativo, FPS, memória e modo de renderização wireframe (F2).
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends CanvasLayer

var _panel: PanelContainer
var _label_info: Label


func _ready() -> void:
	_setup_ui()


func _setup_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(20.0, 20.0)
	_panel.size = Vector2(320.0, 140.0)
	add_child(_panel)

	_label_info = Label.new()
	_label_info.text = "Godotage II — Telemetria de Depuração\nFPS: --\nPos: (0.0, 0.0, 0.0)\nChunk: --\nWireframe: F2"
	_panel.add_child(_label_info)


func update_telemetry(player_pos: Vector3, active_chunk: String, altitude_found: float = 0.0) -> void:
	if not _label_info:
		return

	var fps = Engine.get_frames_per_second()
	_label_info.text = "Godotage II — Depuração 3D (Lineage II)\n" + \
		"FPS: %d | Mem: %.1f MB\n" % [fps, OS.get_static_memory_usage() / (1024.0 * 1024.0)] + \
		"Pos: (%.1f, %.1f, %.1f)m\n" % [player_pos.x, player_pos.y, player_pos.z] + \
		"Chunk Ativo: %s | Altura Solo: %.1fm\n" % [active_chunk if not active_chunk.is_empty() else "Nenhum", altitude_found] + \
		"[F2] Wireframe | [F3] Ocultar HUD"


func toggle_visibility() -> void:
	visible = not visible
