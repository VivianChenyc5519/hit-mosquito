class_name Mosquito
extends CharacterBody2D


signal bite_requested


@export var normal_speed: float = 280.0
@export var boosted_speed: float = 400.0


@onready var mosquito_sprite: AnimatedSprite2D = $MosquitoSprite


var input_enabled: bool = true
var is_boosted: bool = false

var is_dying: bool = false
var is_dead: bool = false


func _ready() -> void:
	mosquito_sprite.animation_finished.connect(
		_on_animation_finished
	)

	mosquito_sprite.play("idle")


func _physics_process(_delta: float) -> void:
	handle_movement()
	update_animation()


func handle_movement() -> void:
	if not input_enabled or is_dying or is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	var current_speed: float = normal_speed

	if is_boosted:
		current_speed = boosted_speed

	velocity = direction * current_speed

	move_and_slide()


func update_animation() -> void:
	# Don't let normal movement animations override death.
	if is_dying or is_dead:
		return

	if velocity.length() > 0.0:
		mosquito_sprite.play("fly")
	else:
		mosquito_sprite.play("idle")


func die() -> void:
	if is_dying or is_dead:
		return

	is_dying = true
	input_enabled = false
	velocity = Vector2.ZERO

	mosquito_sprite.play("die")


func _on_animation_finished() -> void:
	if mosquito_sprite.animation == "die":
		is_dying = false
		is_dead = true

		mosquito_sprite.play("dead")


func set_boosted(boosted: bool) -> void:
	is_boosted = boosted
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("primary_action"):
		request_bite()

func request_bite() -> void:
	if not input_enabled or is_dying or is_dead:
		return
	bite_requested.emit()

func set_input_enabled(enabled: bool) -> void:
	if is_dying or is_dead:
		return

	input_enabled = enabled

	if not enabled:
		velocity = Vector2.ZERO
