## @file player_avatar.gd
## @path res://src/infrastructure/player_avatar.gd
##
## @description
## Nó 3D do Avatar do Jogador (CharacterBody3D) com física local, câmera orbital
## em terceira pessoa (SpringArm3D), suporte a controles WASD e detecção de solo.
##
## @created 2026-08-19
## @updated 2026-08-19
##
## @author Leonardo S. Badaró
extends CharacterBody3D

const MOVE_SPEED := 12.0
const SPRINT_MULTIPLIER := 5.0
const GRAVITY := 20.0
const JUMP_VELOCITY := 7.0

const CAMERA_DEFAULT_SPRING_LENGTH := 12.0
const CAMERA_MIN_ZOOM := 2.0
const CAMERA_MAX_ZOOM := 120.0
const CAMERA_ZOOM_STEP := 3.0
const MOUSE_SENSITIVITY := 0.25

var is_local: bool = true
var peer_id: int = 1
var is_flying: bool = false

var _camera_pivot: Node3D
var _spring_arm: SpringArm3D
var _camera: Camera3D
var _current_zoom: float = CAMERA_DEFAULT_SPRING_LENGTH

var _mesh_instance: MeshInstance3D
var _col_shape: CollisionShape3D


func _ready() -> void:
	_setup_physics()
	_setup_visuals()
	if is_local:
		_setup_camera()


func _setup_physics() -> void:
	_col_shape = CollisionShape3D.new()
	_col_shape.name = "AvatarCollisionShape"
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	_col_shape.shape = capsule
	_col_shape.position = Vector3(0.0, 0.9, 0.0)
	add_child(_col_shape)


func _setup_visuals() -> void:
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "AvatarMesh"
	var capsule_mesh = CapsuleMesh.new()
	capsule_mesh.radius = 0.4
	capsule_mesh.height = 1.8
	_mesh_instance.mesh = capsule_mesh
	_mesh_instance.position = Vector3(0.0, 0.9, 0.0)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.6, 0.9)
	mat.roughness = 0.5
	_mesh_instance.material_override = mat

	add_child(_mesh_instance)


func _setup_camera() -> void:
	_camera_pivot = Node3D.new()
	_camera_pivot.name = "CameraPivot"
	_camera_pivot.position = Vector3(0.0, 1.4, 0.0)
	_camera_pivot.rotation_degrees = Vector3(-20.0, 0.0, 0.0)
	add_child(_camera_pivot)

	_spring_arm = SpringArm3D.new()
	_spring_arm.name = "SpringArm"
	_spring_arm.spring_length = _current_zoom
	_spring_arm.margin = 0.2
	_camera_pivot.add_child(_spring_arm)

	_camera = Camera3D.new()
	_camera.name = "ThirdPersonCamera"
	_camera.current = true
	_spring_arm.add_child(_camera)


func _unhandled_input(event: InputEvent) -> void:
	if not is_local or not _camera_pivot:
		return

	# Alternar Gravidade / Modo Voo com Tecla 'G'
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_G:
			is_flying = !is_flying
			velocity = Vector3.ZERO

	# Rotação de Câmera com Botão Direito do Mouse
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_camera_pivot.rotation_degrees.y -= event.relative.x * MOUSE_SENSITIVITY
		_camera_pivot.rotation_degrees.x -= event.relative.y * MOUSE_SENSITIVITY
		_camera_pivot.rotation_degrees.x = clampf(_camera_pivot.rotation_degrees.x, -65.0, 45.0)

	# Zoom da Câmera com a Roda do Mouse
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_current_zoom = maxf(_current_zoom - CAMERA_ZOOM_STEP, CAMERA_MIN_ZOOM)
			_spring_arm.spring_length = _current_zoom
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_current_zoom = minf(_current_zoom + CAMERA_ZOOM_STEP, CAMERA_MAX_ZOOM)
			_spring_arm.spring_length = _current_zoom


func _physics_process(delta: float) -> void:
	if not is_local:
		return

	var speed = MOVE_SPEED
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= SPRINT_MULTIPLIER

	# Modo Voo (Fly Mode sem gravidade) vs Modo Terrestre
	if is_flying:
		if Input.is_key_pressed(KEY_E):
			velocity.y = speed
		elif Input.is_key_pressed(KEY_Q):
			velocity.y = -speed
		else:
			velocity.y = move_toward(velocity.y, 0.0, speed * delta * 5.0)
	else:
		# Gravidade Normal
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		else:
			velocity.y = 0.0

	# Input de Movimentação (WASD)
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0

	input_dir = input_dir.normalized()

	if _camera_pivot and input_dir.length_squared() > 0.01:
		var cam_yaw = _camera_pivot.global_rotation.y
		var forward = Vector3(-sin(cam_yaw), 0.0, -cos(cam_yaw))
		var right = Vector3(cos(cam_yaw), 0.0, -sin(cam_yaw))
		var move_vec = (forward * (-input_dir.y) + right * input_dir.x).normalized()
		velocity.x = move_vec.x * speed
		velocity.z = move_vec.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0.0, speed * delta * 5.0)

	move_and_slide()
