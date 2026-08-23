## @file fly_camera.gd
## @path res://src/client/infrastructure/fly_camera.gd
##
## @description
## Camera 3D de inspecao livre (Fly Camera) de desenvolvedor para inspecionar cenarios,
## testar streaming de terreno, shaders e posicionamento espacial no cliente.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
class_name FlyCamera
extends Camera3D

# ==============================================================================
# CONFIGURAÇÃO DE CONTROLES
# ==============================================================================

@export var move_speed: float = 40.0
@export var fast_speed_multiplier: float = 3.0
@export var slow_speed_multiplier: float = 0.25
@export var mouse_sensitivity: float = 0.003

var _yaw: float = 0.0
var _pitch: float = 0.0
var _is_mouse_captured: bool = false


func _ready() -> void:
	_yaw = rotation.y
	_pitch = rotation.x


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			set_mouse_captured(not _is_mouse_captured)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and _is_mouse_captured:
			move_speed = clampf(move_speed * 1.15, 2.0, 500.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and _is_mouse_captured:
			move_speed = clampf(move_speed / 1.15, 2.0, 500.0)

	elif event is InputEventMouseMotion and _is_mouse_captured:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch = clampf(
			_pitch - (event.relative.y * mouse_sensitivity),
			-deg_to_rad(89.0),
			deg_to_rad(89.0),
		)
		rotation = Vector3(_pitch, _yaw, 0.0)

	elif event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed and _is_mouse_captured:
			set_mouse_captured(false)


func _process(delta: float) -> void:
	if not _is_mouse_captured:
		return

	var speed = move_speed
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= fast_speed_multiplier
	elif Input.is_key_pressed(KEY_ALT):
		speed *= slow_speed_multiplier

	var move_dir = Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		move_dir -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		move_dir += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		move_dir -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		move_dir += transform.basis.x
	if Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_E):
		move_dir += Vector3.UP
	if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_Q):
		move_dir -= Vector3.UP

	if move_dir.length_squared() > 0.0001:
		global_position += move_dir.normalized() * speed * delta


func set_mouse_captured(captured: bool) -> void:
	_is_mouse_captured = captured
	if _is_mouse_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func is_mouse_captured() -> bool:
	return _is_mouse_captured
