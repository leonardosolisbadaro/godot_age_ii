## @file graphics_telemetry_panel.gd
## @path res://src/debug/panels/graphics_telemetry_panel.gd
##
## @description
## Painel/Janela de telemetria e diagnostico de desempenho grafico e engine da Mini-IDE.
## Herda diretamente de DebugWindow e exibe FPS, Frame Time, Physics Time, Draw Calls,
## Primitivas e uso de VRAM/RAM consultando a API nativa Performance da Godot Engine.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
class_name GraphicsTelemetryPanel
extends DebugWindowClass

# ==============================================================================
# DEPENDÊNCIAS PRELOAD
# ==============================================================================

const DebugWindowClass = preload("res://src/debug/debug_window.gd")

# ==============================================================================
# CONSTANTES DE ATUALIZAÇÃO E CORES
# ==============================================================================

const UPDATE_INTERVAL_SEC: float = 0.2
const COLOR_GOOD: Color = Color(0.35, 0.85, 0.45)
const COLOR_WARN: Color = Color(0.9, 0.8, 0.3)
const COLOR_BAD: Color = Color(0.9, 0.4, 0.35)

# ==============================================================================
# ELEMENTOS VISUAIS ESPECÍFICOS
# ==============================================================================

var _fps_label: Label
var _frame_time_label: Label
var _physics_time_label: Label
var _draw_calls_label: Label
var _primitives_label: Label
var _vram_label: Label
var _ram_label: Label

# ==============================================================================
# ESTADO INTERNO
# ==============================================================================

var _time_since_last_update: float = 0.0
var _current_fps: float = 0.0
var _current_frame_time_ms: float = 0.0
var _current_vram_mb: float = 0.0


func _init() -> void:
	super._init("Telemetria de Gráficos", 320.0)
	_update_metrics()


func _ready() -> void:
	super._ready()
	_update_metrics()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return

	_time_since_last_update += delta
	if _time_since_last_update >= UPDATE_INTERVAL_SEC:
		_time_since_last_update = 0.0
		_update_metrics()

# ==============================================================================
# CONSTRUÇÃO DO CONTEÚDO ESPECÍFICO (OVERRIDE)
# ==============================================================================


func _build_content() -> void:
	if _fps_label != null or _content_vbox == null:
		return

	_fps_label = Label.new()
	_fps_label.name = "FpsLabel"
	_content_vbox.add_child(_fps_label)

	var sep = HSeparator.new()
	_content_vbox.add_child(sep)

	_frame_time_label = Label.new()
	_frame_time_label.name = "FrameTimeLabel"
	_content_vbox.add_child(_frame_time_label)

	_physics_time_label = Label.new()
	_physics_time_label.name = "PhysicsTimeLabel"
	_content_vbox.add_child(_physics_time_label)

	_draw_calls_label = Label.new()
	_draw_calls_label.name = "DrawCallsLabel"
	_content_vbox.add_child(_draw_calls_label)

	_primitives_label = Label.new()
	_primitives_label.name = "PrimitivesLabel"
	_content_vbox.add_child(_primitives_label)

	_vram_label = Label.new()
	_vram_label.name = "VramLabel"
	_content_vbox.add_child(_vram_label)

	_ram_label = Label.new()
	_ram_label.name = "RamLabel"
	_content_vbox.add_child(_ram_label)

# ==============================================================================
# ATUALIZAÇÃO DE MÉTRICAS DA ENGINE
# ==============================================================================


func _update_metrics() -> void:
	if _fps_label == null:
		return

	_current_fps = Performance.get_monitor(Performance.TIME_FPS)
	var process_time = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_time = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_current_frame_time_ms = process_time

	var draw_calls = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var primitives = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var vram_mb = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / (1024.0 * 1024.0)
	var ram_mb = Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)
	_current_vram_mb = vram_mb

	_fps_label.text = "FPS: %d" % int(_current_fps)
	if _current_fps >= 55.0:
		_fps_label.add_theme_color_override("font_color", COLOR_GOOD)
	elif _current_fps >= 30.0:
		_fps_label.add_theme_color_override("font_color", COLOR_WARN)
	else:
		_fps_label.add_theme_color_override("font_color", COLOR_BAD)

	_frame_time_label.text = "Frame Time (CPU): %.2f ms" % process_time
	_physics_time_label.text = "Physics Time: %.2f ms" % physics_time
	_draw_calls_label.text = "Draw Calls: %d" % draw_calls
	_primitives_label.text = "Primitivas 3D: %d" % primitives
	_vram_label.text = "VRAM Usada: %.1f MB" % vram_mb
	_ram_label.text = "RAM Estatica: %.1f MB" % ram_mb

# ==============================================================================
# MÉTODOS DE CONSULTA PARA TESTES
# ==============================================================================


func get_current_fps() -> float:
	return _current_fps


func get_current_frame_time_ms() -> float:
	return _current_frame_time_ms


func get_current_vram_mb() -> float:
	return _current_vram_mb
