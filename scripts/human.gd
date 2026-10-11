class_name Human
extends CharacterBody2D

signal slap_requested

@export var move_speed := 220.0

@onready var racket_pivot: Node2D = $RacketPivot

var input_enabled := true
var is_stunned := false


func _physics_process(_delta: float) -> void:
	handle_movement()
	handle_aim()


func handle_movement() -> void:
	if not input_enabled or is_stunned:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	velocity = direction * move_speed
	move_and_slide()


func handle_aim() -> void:
	racket_pivot.look_at(get_global_mouse_position())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("slap"):
		request_slap()


func request_slap() -> void:
	if not input_enabled or is_stunned:
		return

	slap_requested.emit()


func set_stunned(stunned: bool) -> void:
	is_stunned = stunned

	if stunned:
		velocity = Vector2.ZERO


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled

	if not enabled:
		velocity = Vector2.ZERO
