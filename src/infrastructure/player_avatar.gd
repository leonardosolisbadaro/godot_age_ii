## @file player_avatar.gd
## @path res://src/infrastructure/player_avatar.gd
##
## @description
## Nó 3D do Avatar do Jogador (CharacterBody3D) com física local, câmera orbital
## em terceira pessoa (SpringArm3D), suporte a controles WASD e detecção de solo.
##
## @created 2026-08-19
## @updated 2026-08-20
##
## @author Leonardo S. Badaró
extends CharacterBody3D

# ==============================================================================
# CONSTANTES SEMÂNTICAS DE FÍSICA E CÂMERA
# ==============================================================================

## @const MOVE_SPEED (float)
## O que: Velocidade básica de caminhada em metros por segundo (12.0 m/s).
## Porque: Navegação ágil de exploração no mapa de testes.
const MOVE_SPEED: float = 12.0

## @const SPRINT_MULTIPLIER (float)
## O que: Multiplicador de velocidade ao pressionar Shift (5.0x = 60.0 m/s).
## Porque: Permite transição rápida entre vilas e regiões distantes.
const SPRINT_MULTIPLIER: float = 5.0

## @const GRAVITY (float)
## O que: Aceleração gravitacional vertical para baixo em m/s² (20.0 m/s²).
## Porque: Resposta ágil de queda e contato firme com o terreno.
const GRAVITY: float = 20.0

## @const JUMP_VELOCITY (float)
## O que: Impulso vertical inicial de salto em m/s (7.0 m/s).
## Porque: Altura de salto proporcional à escala humana.
const JUMP_VELOCITY: float = 7.0

## @const DECELERATION_RATE (float)
## O que: Fator de atenuação inercial de movimento ao soltar os controles (5.0).
## Porque: Parada suave e natural.
const DECELERATION_RATE: float = 5.0

## @const CAPSULE_RADIUS (float)
## O que: Raio da cápsula de colisão do avatar em metros (0.4m = 40cm).
## Porque: Largura dos ombros do personagem humanoide.
const CAPSULE_RADIUS: float = 0.4

## @const CAPSULE_HEIGHT (float)
## O que: Altura total da cápsula de colisão em metros (1.8m = 180cm).
## Porque: Estatura humana padrão.
const CAPSULE_HEIGHT: float = 1.8

## @const MAX_STEP_HEIGHT (float)
## O que: Altura máxima de degrau que o avatar transpõe automaticamente em metros (0.40m = 40cm).
## Porque: Permite subir calçadas, escadas e soleiras de portas sem travar em quinas de 90°.
const MAX_STEP_HEIGHT: float = 0.60

## @const PIVOT_HEIGHT (float)
## O que: Altura do pivô da câmera orbital em relação aos pés do avatar (1.4m).
## Porque: Linha de visão na altura do tórax/cabeça.
const PIVOT_HEIGHT: float = 1.4

## @const CAMERA_DEFAULT_SPRING_LENGTH (float)
## O que: Distância inicial padrão da câmera orbital em metros (12.0m).
## Porque: Visão em terceira pessoa ampla clássica de MMORPG.
const CAMERA_DEFAULT_SPRING_LENGTH: float = 12.0

## @const CAMERA_MIN_ZOOM (float)
## O que: Distância mínima permitida da câmera em metros (2.0m).
## Porque: Evita corte da câmera no interior da malha do avatar.
const CAMERA_MIN_ZOOM: float = 2.0

## @const CAMERA_MAX_ZOOM (float)
## O que: Distância máxima permitida da câmera em metros (120.0m).
## Porque: Visão panorâmica tática.
const CAMERA_MAX_ZOOM: float = 120.0

## @const CAMERA_ZOOM_STEP (float)
## O que: Incremento de distância por clique na roda do mouse (3.0m).
## Porque: Zoom gradual e responsivo.
const CAMERA_ZOOM_STEP: float = 3.0

## @const MOUSE_SENSITIVITY (float)
## O que: Sensibilidade angular da rotação de câmera com mouse (0.25).
## Porque: Rotação suave em 360 graus.
const MOUSE_SENSITIVITY: float = 0.25

## @const CAMERA_PITCH_MIN_DEG (float)
## O que: Ângulo mínimo de inclinação vertical da câmera em graus (-65.0°).
## Porque: Impede inversão de visão por baixo do solo.
const CAMERA_PITCH_MIN_DEG: float = -65.0

## @const CAMERA_PITCH_MAX_DEG (float)
## O que: Ângulo máximo de inclinação vertical da câmera em graus (45.0°).
## Porque: Limita visão zenital superior.
const CAMERA_PITCH_MAX_DEG: float = 45.0

## @const CAMERA_SPRING_MARGIN (float)
## O que: Margem de oclusão de colisão da haste de mola da câmera em metros (0.2m).
## Porque: Evita recortes de geometria no frustum da câmera.
const CAMERA_SPRING_MARGIN: float = 0.2

## @const MIN_INPUT_THRESHOLD_SQ (float)
## O que: Limiar quadrático mínimo de magnitude de vetor de entrada (0.01).
## Porque: Previne micro-derivas de joysticks e teclado.
const MIN_INPUT_THRESHOLD_SQ: float = 0.01

# ==============================================================================
# PROPRIEDADES E NÓS
# ==============================================================================

var is_local: bool = true
var peer_id: int = 1
var is_flying: bool = false
var is_sprinting: bool = false
var is_noclip: bool = false
var speed_hack_multiplier: float = 1.0
var is_ui_hovered_callback: Callable
var _packet_seq: int = 0

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
	capsule.radius = CAPSULE_RADIUS
	capsule.height = CAPSULE_HEIGHT
	_col_shape.shape = capsule
	_col_shape.position = Vector3(0.0, CAPSULE_HEIGHT / 2.0, 0.0)
	add_child(_col_shape)


func _setup_visuals() -> void:
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "AvatarMesh"
	var capsule_mesh = CapsuleMesh.new()
	capsule_mesh.radius = CAPSULE_RADIUS
	capsule_mesh.height = CAPSULE_HEIGHT
	_mesh_instance.mesh = capsule_mesh
	_mesh_instance.position = Vector3(0.0, CAPSULE_HEIGHT / 2.0, 0.0)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.6, 0.9)
	mat.roughness = 0.5
	_mesh_instance.material_override = mat

	add_child(_mesh_instance)


func _setup_camera() -> void:
	_camera_pivot = Node3D.new()
	_camera_pivot.name = "CameraPivot"
	_camera_pivot.position = Vector3(0.0, PIVOT_HEIGHT, 0.0)
	_camera_pivot.rotation_degrees = Vector3(-20.0, 0.0, 0.0)
	add_child(_camera_pivot)

	_spring_arm = SpringArm3D.new()
	_spring_arm.name = "SpringArm"
	_spring_arm.spring_length = _current_zoom
	_spring_arm.margin = CAMERA_SPRING_MARGIN
	_camera_pivot.add_child(_spring_arm)

	_camera = Camera3D.new()
	_camera.name = "ThirdPersonCamera"
	_camera.current = true
	_spring_arm.add_child(_camera)


func _unhandled_input(event: InputEvent) -> void:
	if not is_local or not _camera_pivot:
		return

	# Alternar Gravidade / Modo Voo com Tecla 'G' (ignora se algum campo de texto da UI estiver focado)
	if event is InputEventKey and event.pressed and not event.echo:
		var has_ui_focus = (get_viewport() and get_viewport().gui_get_focus_owner() != null)
		if not has_ui_focus:
			if event.keycode == KEY_G:
				is_flying = !is_flying
				velocity = Vector3.ZERO
			elif event.keycode == KEY_SPACE:
				is_sprinting = !is_sprinting

	# Rotação de Câmera com Botão Direito do Mouse
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_camera_pivot.rotation_degrees.y -= event.relative.x * MOUSE_SENSITIVITY
		_camera_pivot.rotation_degrees.x -= event.relative.y * MOUSE_SENSITIVITY
		_camera_pivot.rotation_degrees.x = clampf(
			_camera_pivot.rotation_degrees.x,
			CAMERA_PITCH_MIN_DEG,
			CAMERA_PITCH_MAX_DEG,
		)

	# Zoom da Câmera com a Roda do Mouse (ignora se Ctrl, Alt ou Shift estiver pressionado ou se o cursor estiver sobre a UI)
	if event is InputEventMouseButton and event.pressed:
		if event.ctrl_pressed or event.shift_pressed or event.alt_pressed:
			return
		if is_ui_hovered_callback.is_valid() and is_ui_hovered_callback.call():
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_current_zoom = maxf(_current_zoom - CAMERA_ZOOM_STEP, CAMERA_MIN_ZOOM)
			_spring_arm.spring_length = _current_zoom
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_current_zoom = minf(_current_zoom + CAMERA_ZOOM_STEP, CAMERA_MAX_ZOOM)
			_spring_arm.spring_length = _current_zoom


func _physics_process(delta: float) -> void:
	if not is_local:
		return

	var speed = MOVE_SPEED * speed_hack_multiplier
	if is_sprinting:
		speed *= SPRINT_MULTIPLIER

	var has_ui_focus = (get_viewport() and get_viewport().gui_get_focus_owner() != null)

	# Modo Voo (Fly Mode sem gravidade) vs Modo Terrestre vs No-Clip
	if is_noclip:
		if not has_ui_focus:
			if Input.is_key_pressed(KEY_E):
				velocity.y = speed
			elif Input.is_key_pressed(KEY_Q):
				velocity.y = -speed
			else:
				velocity.y = 0.0
		else:
			velocity.y = 0.0
	elif is_flying:
		if not has_ui_focus and Input.is_key_pressed(KEY_E):
			velocity.y = speed
		elif not has_ui_focus and Input.is_key_pressed(KEY_Q):
			velocity.y = -speed
		else:
			velocity.y = move_toward(velocity.y, 0.0, speed * delta * DECELERATION_RATE)
	else:
		# Gravidade Normal
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		else:
			velocity.y = 0.0

	# Input de Movimentação (Estritamente WASD quando a UI NÃO estiver em foco de digitação)
	var input_dir := Vector2.ZERO
	if not has_ui_focus:
		if Input.is_key_pressed(KEY_W):
			input_dir.y -= 1.0
		if Input.is_key_pressed(KEY_S):
			input_dir.y += 1.0
		if Input.is_key_pressed(KEY_A):
			input_dir.x -= 1.0
		if Input.is_key_pressed(KEY_D):
			input_dir.x += 1.0

	input_dir = input_dir.normalized()

	if _camera_pivot and input_dir.length_squared() > MIN_INPUT_THRESHOLD_SQ:
		var cam_yaw = _camera_pivot.global_rotation.y
		var forward = Vector3(-sin(cam_yaw), 0.0, -cos(cam_yaw))
		var right = Vector3(cos(cam_yaw), 0.0, -sin(cam_yaw))
		var move_vec = (forward * (-input_dir.y) + right * input_dir.x).normalized()
		velocity.x = move_vec.x * speed
		velocity.z = move_vec.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * delta * DECELERATION_RATE)
		velocity.z = move_toward(velocity.z, 0.0, speed * delta * DECELERATION_RATE)

	var horiz_vel = Vector3(velocity.x, 0.0, velocity.z)
	var was_grounded = is_on_floor()

	if is_noclip:
		global_position += velocity * delta
	else:
		move_and_slide()

		# Rotina de Stair Stepping (Subida de Degraus e Soleiras de Portas)
		if was_grounded and horiz_vel.length_squared() > 0.1 and not is_flying:
			_handle_stair_step_up(horiz_vel, delta)

	# Transmissão de Estado Autoritativo para o Servidor (32-bit Float UDP)
	if is_inside_tree() and is_local:
		var qn = get_node_or_null("/root/QuanticNet")
		if qn and qn.has_method("send_game_packet") and qn.has_method("get_state"):
			if qn.get_state() == 3: # ConnectionState.CONNECTED
				_packet_seq = (_packet_seq + 1) & 0xFFFFFFFF
				var pkt = PackedByteArray()
				pkt.resize(25)
				pkt.encode_u32(0, _packet_seq)
				pkt.encode_float(4, global_position.x)
				pkt.encode_float(8, global_position.y)
				pkt.encode_float(12, global_position.z)
				pkt.encode_float(16, rotation.y)
				var custom_flags = (1 if is_flying else 0) | (2 if is_sprinting else 0) | (4 if is_noclip else 0)
				pkt.encode_u8(20, custom_flags)
				pkt.encode_float(21, delta)
				qn.send_game_packet(1, 101, pkt, false)


func reconcile_server_state(pos: Vector3, _rot: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO


func set_speedhack(active: bool, mult: float = 5.0) -> void:
	speed_hack_multiplier = mult if active else 1.0


func set_noclip(active: bool) -> void:
	is_noclip = active
	if _col_shape:
		_col_shape.disabled = active


func apply_forced_teleport(forward_dist: float = 30.0) -> void:
	var yaw = _camera_pivot.global_rotation.y if _camera_pivot else 0.0
	var forward = Vector3(-sin(yaw), 0.0, -cos(yaw)).normalized()
	global_position += forward * forward_dist


func apply_flyhack(altitude_offset: float = 15.0) -> void:
	global_position.y += altitude_offset
	velocity.y = 0.0


func _handle_stair_step_up(horiz_vel: Vector3, delta: float) -> void:
	if not is_on_wall():
		return

	var step_motion = horiz_vel.normalized() * (horiz_vel.length() * delta + 0.05)

	# 1. Testa elevação vertical de MAX_STEP_HEIGHT
	var up_transform = global_transform.translated(Vector3(0.0, MAX_STEP_HEIGHT, 0.0))
	var test_collision = KinematicCollision3D.new()

	# Se o espaço acima estiver livre:
	if not test_move(global_transform, Vector3(0.0, MAX_STEP_HEIGHT, 0.0), test_collision):
		# 2. Testa avanço horizontal no topo do degrau
		if not test_move(up_transform, step_motion, test_collision):
			# 3. Testa descida para o topo do degrau
			var down_vec = Vector3(0.0, -MAX_STEP_HEIGHT, 0.0)
			if test_move(up_transform.translated(step_motion), down_vec, test_collision):
				var surface_normal = test_collision.get_normal()
				if surface_normal.y >= 0.5: # Chão caminhável
					global_position = up_transform.origin + step_motion + (down_vec.normalized() * test_collision.get_travel().length())
					velocity.y = 0.0
