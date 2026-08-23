## @file movement_intent.gd
## @path res://src/core/domain/movement_intent.gd
##
## @description
## Entidade pura do Core Domain representando a intenção instantânea de deslocamento
## do jogador (direção de input normalizada, corrida, pulo e orientação angular).
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
class_name MovementIntent
extends RefCounted

# ==============================================================================
# ESTADO DE INTENÇÃO
# ==============================================================================

## Vetor de entrada 2D normalizado no plano horizontal (X = Direita/Esquerda, Y = Frente/Trás).
var input_vector: Vector2 = Vector2.ZERO

## Indica se o jogador está com intenção de correr (true) ou caminhar (false).
var is_running: bool = true

## Indica se o comando de salto foi acionado neste frame/tick.
var is_jumping: bool = false

## Orientação angular do olhar/câmera em radianos (Yaw ao redor do eixo Y).
var yaw_radians: float = 0.0


func _init(
	p_input: Vector2 = Vector2.ZERO,
	p_is_running: bool = true,
	p_is_jumping: bool = false,
	p_yaw: float = 0.0,
) -> void:
	input_vector = p_input.normalized() if p_input.length_squared() > 1.0 else p_input
	is_running = p_is_running
	is_jumping = p_is_jumping
	yaw_radians = p_yaw
