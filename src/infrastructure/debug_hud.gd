## @file debug_hud.gd
## @path res://src/infrastructure/debug_hud.gd
##
## @description
## Camada de interface de depuração (CanvasLayer) exibindo telemetria em tempo real
## de coordenadas mundiais, chunk ativo, FPS, memória e modo de renderização wireframe (F2).
##
## @created 2026-08-19
## @updated 2026-08-20
##
## @author Leonardo S. Badaró
extends CanvasLayer

# ==============================================================================
# CONSTANTES SEMÂNTICAS DE INTERFACE
# ==============================================================================

## @const PANEL_POSITION (Vector2)
## O que: Posição do painel principal de telemetria no canto superior esquerdo (20px, 20px).
## Porque: Posição desobstruída para dados em tempo real.
const PANEL_POSITION: Vector2 = Vector2(20.0, 20.0)

## @const PANEL_SIZE (Vector2)
## O que: Dimensão do painel principal de telemetria (340px x 140px).
## Porque: Enquadramento compacto do texto de status.
const PANEL_SIZE: Vector2 = Vector2(340.0, 140.0)

## @const INSPECTOR_PANEL_POSITION (Vector2)
## O que: Posição do painel de inspeção de materiais no canto superior direito (800px, 20px).
## Porque: Painel auxiliar de diagnóstico visual.
const INSPECTOR_PANEL_POSITION: Vector2 = Vector2(800.0, 20.0)

## @const INSPECTOR_PANEL_SIZE (Vector2)
## O que: Dimensão do painel de inspeção (460px x 260px).
## Porque: Exibe listas de superfícies e status de texturas.
const INSPECTOR_PANEL_SIZE: Vector2 = Vector2(460.0, 260.0)

## @const BYTES_TO_MB (float)
## O que: Divisor para conversão de bytes para Megabytes (1024 * 1024 = 1048576.0).
## Porque: Exibição legível do consumo de RAM do engine.
const BYTES_TO_MB: float = 1048576.0

# ==============================================================================
# PROPRIEDADES DE UI
# ==============================================================================

var _panel: PanelContainer
var _label_info: Label
var _inspector_panel: PanelContainer
var _label_inspector: Label


func _ready() -> void:
	_setup_ui()


func _setup_ui() -> void:
	# Painel de Telemetria Geral (Esquerda)
	_panel = PanelContainer.new()
	_panel.position = PANEL_POSITION
	_panel.size = PANEL_SIZE
	add_child(_panel)

	_label_info = Label.new()
	_label_info.text = "Godotage II — Telemetria de Depuração\nFPS: --\nPos: (0.0, 0.0, 0.0)\nChunk: --\nWireframe: F2"
	_panel.add_child(_label_info)

	# Painel do Inspetor de Objetos e Materiais pelo Mouse (Direita)
	_inspector_panel = PanelContainer.new()
	_inspector_panel.anchor_left = 1.0
	_inspector_panel.anchor_right = 1.0
	_inspector_panel.position = INSPECTOR_PANEL_POSITION
	_inspector_panel.size = INSPECTOR_PANEL_SIZE
	_inspector_panel.visible = false
	add_child(_inspector_panel)

	_label_inspector = Label.new()
	_label_inspector.text = "Inspetor de Objetos (Mouse)"
	_inspector_panel.add_child(_label_inspector)


func update_telemetry(
	player_pos: Vector3,
	active_chunk: String,
	altitude_found: float = 0.0,
	wireframe_on: bool = false,
) -> void:
	if not _label_info:
		return

	var fps = Engine.get_frames_per_second()
	var mode_str = ""
	if wireframe_on:
		mode_str += " [WIREFRAME 60FPS]"

	_label_info.text = "Godotage II — Depuração 3D (Lineage II)%s\n" % mode_str + "FPS: %d | Mem: %.1f MB\n" % [
		fps,
		OS.get_static_memory_usage() / BYTES_TO_MB,
	] + "Pos: (%.1f, %.1f, %.1f)m\n" % [player_pos.x, player_pos.y, player_pos.z] + "Chunk Ativo: %s | Altura Solo: %.1fm\n" % [
		active_chunk if not active_chunk.is_empty() else "Nenhum",
		altitude_found,
	] + "[F2] HUD | [F3] Wireframe | [F5] Colisão | [F10] Água | [F12] Sombras"


func update_inspector_info(data: Dictionary) -> void:
	if not _inspector_panel or not _label_inspector:
		return

	if not data.get("found", false):
		_inspector_panel.visible = false
		return

	_inspector_panel.visible = true
	var p = data.get("position", Vector3.ZERO)
	var text = "🔍 [INSPETOR DE MATERIAIS / MOUSE]\n" + "Ator: %s\n" % data.get("actor_name", "--") + "Modelo: %s (Pacote: %s)\n" % [
		data.get("mesh_name", "--"),
		data.get("package_name", "--"),
	] + "Posição: (%.1f, %.1f, %.1f)m | Dist: %.1fm\n" % [p.x, p.y, p.z, data.get("distance", 0.0)] + "--------------------------------------------------\n" + "Superfícies & Texturas (%d):\n" % data \
			.get("surfaces", []) \
			.size()

	var surfs = data.get("surfaces", [])
	for s in surfs:
		var status_str = s.get("status", "MISSING")
		var icon = "✅" if "OK" in status_str else "❌"
		text += "%s [%d] %s\n    └─ %s (%s)\n" % [
			icon,
			s.get("index", 0),
			s.get("name", ""),
			status_str,
			s.get("texture_path", "N/A"),
		]

	_label_inspector.text = text


func toggle_visibility() -> void:
	visible = not visible
