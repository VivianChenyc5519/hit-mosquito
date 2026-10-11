class_name Human
extends CharacterBody2D

signal slap_requested

@export var move_speed:= 220.0
@export var aim_rotation_speed: float = 8.0

# Racket_pivot controls the mouse rotation
@onready var racket_pivot: Node2D = $RacketPivot
@onready var racket_sprite: AnimatedSprite2D = $RacketSprite
@onready var slap_area: Area2D = $RacketPivot/SlapArea
@onready var slap_polygon: CollisionPolygon2D = $RacketPivot/SlapArea/CollisionPolygon2D


func _ready() -> void:
	racket_sprite.play("idle")
	racket_sprite.animation_finished.connect(_on_racket_animation_finished)


var input_enabled := true
var is_stunned := false


func _physics_process(_delta: float) -> void:
	handle_movement()
	handle_aim(_delta)


func handle_movement() -> void:
	if not input_enabled or is_stunned:
		velocity = Vector2.ZERO
		return

	var direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	velocity = direction * move_speed
	move_and_slide()


func handle_aim(delta: float) -> void:
	var direction: Vector2 = (
		get_global_mouse_position()
		- racket_pivot.global_position
	)

	var target_angle := direction.angle()

	racket_pivot.rotation = lerp_angle(
		racket_pivot.rotation,
		target_angle,
		aim_rotation_speed * delta
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("primary_action"):
		request_slap()


func request_slap() -> void:
	if not input_enabled or is_stunned:
		return
	slap_requested.emit()
	
	
func play_hitting_animation() -> void:
	racket_sprite.play("hitting")


func play_hit_animation() -> void:
	racket_sprite.play("hit")


func play_idle_animation() -> void:
	racket_sprite.play("idle")


func set_stunned(stunned: bool) -> void:
	is_stunned = stunned

	if stunned:
		velocity = Vector2.ZERO


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled

	if not enabled:
		velocity = Vector2.ZERO
		
	
func _on_racket_animation_finished() -> void:
	if racket_sprite.animation == "hitting":
		racket_sprite.play("idle")

	elif racket_sprite.animation == "hit":
		racket_sprite.play("idle")
		
func can_hit_target(target: Node2D) -> bool:
	return slap_area.overlaps_body(target)
