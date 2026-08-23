## @file player_avatar_view.gd
## @path res://src/client/infrastructure/player_avatar_view.gd
##
## @description
## Nó 3D de apresentação do Avatar do Jogador (Local ou Remoto).
## Implementa controle em 3ª pessoa orbitável com mouse, predição de movimento local (60Hz),
## interpolação para avatares remotos e aderência contínua ao terreno.
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
class_name PlayerAvatarView
extends Node3D

# ==============================================================================
# DEPENDÊNCIAS PRELOAD
# ==============================================================================

const KinematicStateClass = preload("res://src/core/domain/kinematic_state.gd")
const MovementIntentClass = preload("res://src/core/domain/movement_intent.gd")
const PlayerStatsClass = preload("res://src/core/domain/player_stats.gd")
const PredictPlayerMovementUseCaseClass = preload(
	"res://src/core/use_cases/predict_player_movement_use_case.gd"
)
const SampleTerrainAltitudeUseCaseClass = preload(
	"res://src/core/use_cases/sample_terrain_altitude_use_case.gd"
)
const ScaleConverterClass = preload("res://src/core/domain/scale_converter.gd")
const ChunkResourceAdapterClass = preload("res://src/client/adapters/chunk_resource_adapter.gd")

# ==============================================================================
# PROPRIEDADES E CONFIGURAÇÕES
# ==============================================================================

@export var is_local: bool = true
@export var is_active: bool = true
@export var peer_id: int = 1
@export var player_name: String = "Player"

var stats: RefCounted = null
var current_state: RefCounted = null
var target_remote_state: RefCounted = null
var client_adapter: RefCounted = null

# Amostragem de terreno
var altitude_sampler: GDScript = SampleTerrainAltitudeUseCaseClass
var terrain_chunks_map: Dictionary = { } # { "17_25": TerrainChunkData }

# Câmera e Órbita de 3ª pessoa
var _spring_arm: SpringArm3D = null
var _camera: Camera3D = null
var _camera_yaw: float = 0.0
var _camera_pitch: float = -0.3
var _camera_distance: float = 6.0
var _is_orbiting: bool = false

# Componentes Visuais
var _mesh_instance: MeshInstance3D = null
var _pointer_mesh: MeshInstance3D = null

# Input Intent
var _current_intent: RefCounted = null


func _init(p_is_local: bool = true, p_peer_id: int = 1) -> void:
	is_local = p_is_local
	peer_id = p_peer_id
	stats = PlayerStatsClass.new()
	current_state = KinematicStateClass.new(0, Vector3.ZERO, Vector3.ZERO, 0.0, true)
	_current_intent = MovementIntentClass.new()
	altitude_sampler = SampleTerrainAltitudeUseCaseClass


func _ready() -> void:
	_setup_visuals()
	if is_local:
		_setup_third_person_camera()


func _unhandled_input(event: InputEvent) -> void:
	if not is_local or not is_active:
		return

	# Controle de Órbita com Botão Direito do Mouse
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_is_orbiting = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _is_orbiting else Input.MOUSE_MODE_VISIBLE
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_distance = clampf(_camera_distance - 0.5, 2.0, 30.0)
			if _spring_arm:
				_spring_arm.spring_length = _camera_distance
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = clampf(_camera_distance + 0.5, 2.0, 30.0)
			if _spring_arm:
				_spring_arm.spring_length = _camera_distance

	# Rotação da câmera
	if event is InputEventMouseMotion and _is_orbiting:
		var sensitivity = 0.003
		_camera_yaw -= event.relative.x * sensitivity
		_camera_pitch = clampf(_camera_pitch - event.relative.y * sensitivity, -1.3, 0.5)
		_update_camera_transform()


func _physics_process(delta: float) -> void:
	if _spring_arm != null and is_local:
		_spring_arm.global_position = global_position + Vector3(0.0, 1.6, 0.0)
		_spring_arm.rotation = Vector3(_camera_pitch, _camera_yaw, 0.0)

	if is_local:
		if is_active:
			_process_local_movement(delta)
	else:
		_process_remote_interpolation(delta)


func _process_local_movement(delta: float) -> void:
	var raw_input = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		raw_input.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		raw_input.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		raw_input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		raw_input.x += 1.0

	var is_running = not Input.is_key_pressed(KEY_SHIFT)

	# Atualiza a intenção
	_current_intent = MovementIntentClass.new(
		raw_input,
		is_running,
		false,
		_camera_yaw,
	)

	# Obtém os dados do chunk atual para ajuste de terreno
	var chunk_data = _get_current_chunk_data(global_position)

	# Predição Determinística Local do Core Domain
	current_state = PredictPlayerMovementUseCaseClass.execute(
		current_state,
		_current_intent,
		stats,
		delta,
		altitude_sampler,
		chunk_data,
	)

	# Aplica no nó 3D
	global_position = current_state.position

	# Rotaciona o modelo na direção do movimento orientada pela câmera
	if raw_input.length_squared() > 0.01:
		var move_angle = atan2(-raw_input.x, -raw_input.y) + _camera_yaw
		rotation.y = lerp_angle(rotation.y, move_angle, delta * 15.0)

	# Submete o estado previsto local ao servidor via canal nativo QuanticNet
	if (
		client_adapter != null and client_adapter.has_method("submit_state")
		and client_adapter.has_method("is_connected_to_server")
	):
		if client_adapter.is_connected_to_server():
			client_adapter.submit_state(
				current_state.position,
				Vector3(0.0, rotation.y, 0.0),
				0,
				delta,
			)


func _process_remote_interpolation(delta: float) -> void:
	if target_remote_state == null:
		return

	# Interpolação suave de posição e rotação
	global_position = global_position.lerp(target_remote_state.position, delta * 15.0)
	rotation.y = lerp_angle(rotation.y, target_remote_state.yaw_radians, delta * 15.0)


func _get_current_chunk_data(world_pos: Vector3) -> RefCounted:
	var coords = ScaleConverterClass.world_pos_to_chunk_coords(world_pos)
	var name_key = ScaleConverterClass.chunk_coords_to_name(coords)
	if terrain_chunks_map.has(name_key):
		return terrain_chunks_map[name_key]

	var loaded = ChunkResourceAdapterClass.load_terrain_chunk_data(name_key)
	if loaded != null:
		terrain_chunks_map[name_key] = loaded
		return loaded
	return null


func _setup_visuals() -> void:
	# Cápsula do Corpo (1.8m de altura)
	_mesh_instance = MeshInstance3D.new()
	var capsule = CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	_mesh_instance.mesh = capsule
	_mesh_instance.position.y = 0.9

	var mat = StandardMaterial3D.new()
	if is_local:
		mat.albedo_color = Color(0.2, 0.8, 1.0) # Ciano/Azul Heróico para jogador local
		mat.metallic = 0.4
		mat.roughness = 0.3
	else:
		mat.albedo_color = Color(1.0, 0.4, 0.2) # Laranja/Vermelho para outros peers
		mat.metallic = 0.2
		mat.roughness = 0.5
	_mesh_instance.material_override = mat
	add_child(_mesh_instance)

	# Ponteiro Visor / Direção da Face
	_pointer_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.2, 0.15, 0.4)
	_pointer_mesh.mesh = box
	_pointer_mesh.position = Vector3(0.0, 1.5, -0.35)

	var p_mat = StandardMaterial3D.new()
	p_mat.albedo_color = Color(1.0, 0.9, 0.2)
	p_mat.emission_enabled = true
	p_mat.emission = Color(1.0, 0.8, 0.1)
	p_mat.emission_energy_multiplier = 0.5
	_pointer_mesh.material_override = p_mat
	add_child(_pointer_mesh)


func _setup_third_person_camera() -> void:
	_spring_arm = SpringArm3D.new()
	_spring_arm.name = "SpringArm"
	_spring_arm.top_level = true
	_spring_arm.spring_length = _camera_distance
	_spring_arm.margin = 0.2
	add_child(_spring_arm)
	if is_inside_tree() and _spring_arm.is_inside_tree():
		_spring_arm.global_position = global_position + Vector3(0.0, 1.6, 0.0)
	else:
		_spring_arm.position = Vector3(0.0, 1.6, 0.0)

	_camera = Camera3D.new()
	_camera.name = "ThirdPersonCamera"
	_camera.current = true
	_spring_arm.add_child(_camera)

	_update_camera_transform()


func _update_camera_transform() -> void:
	if _spring_arm:
		_spring_arm.rotation = Vector3(_camera_pitch, _camera_yaw, 0.0)


## Define a câmera do avatar como ativa.
func make_camera_current() -> void:
	if _camera:
		_camera.current = true


## Teleporta o avatar para uma coordenada mundial e atualiza o estado cinemático.
func teleport(world_pos: Vector3) -> void:
	var chunk_data = _get_current_chunk_data(world_pos)
	if chunk_data != null and altitude_sampler != null:
		var ground_y = altitude_sampler.execute(chunk_data, world_pos)
		world_pos.y = ground_y

	if is_inside_tree():
		global_position = world_pos
	else:
		position = world_pos

	if _spring_arm != null:
		if is_inside_tree() and _spring_arm.is_inside_tree():
			_spring_arm.global_position = world_pos + Vector3(0.0, 1.6, 0.0)
		else:
			_spring_arm.position = Vector3(0.0, 1.6, 0.0)

	var prev_tick = current_state.tick if current_state != null else 0
	current_state = KinematicStateClass.new(
		prev_tick,
		world_pos,
		Vector3.ZERO,
		_camera_yaw,
		true,
	)
