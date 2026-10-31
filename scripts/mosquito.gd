class_name Mosquito
extends CharacterBody2D


signal bite_requested


@export var normal_speed: float = 280.0
@export var boosted_speed: float = 400.0


@onready var mosquito_sprite: AnimatedSprite2D = $MosquitoSprite
@onready var bite_area: Area2D = $BiteArea
@onready var coolBar: TextureProgressBar = $CoolDown


var input_enabled: bool = true
var is_boosted: bool = false

var is_dying: bool = false
var is_dead: bool = false


const CooldownRing = preload("res://scripts/cooldown_ring.gd")
var cooldown_ring: CooldownRing


func start_cooldown(duration: float) -> void:
	# Only the mosquito's own player needs to see the bite cooldown.
	if is_multiplayer_authority():
		cooldown_ring.start(duration)


var buzz: AudioStreamPlayer2D
var listener: AudioListener2D
var _sprite_tween: Tween


func _ready() -> void:
	coolBar.visible = false  # replaced by the code-drawn ring

	# Always-on buzzing loop. The human's AudioListener2D makes it louder when close.
	buzz = Sfx.make_buzz_player()
	add_child(buzz)
	buzz.play()
	listener = AudioListener2D.new()
	add_child(listener)

	cooldown_ring = CooldownRing.new()
	cooldown_ring.position = Vector2(0, -26)
	cooldown_ring.ring_color = Color(1, 0.3, 0.3)
	add_child(cooldown_ring)
	mosquito_sprite.animation_finished.connect(
		_on_animation_finished
	)

	mosquito_sprite.play("idle")


var _last_pos: Vector2 = Vector2.ZERO
var _remote_moving: bool = false


func _physics_process(_delta: float) -> void:
	if is_multiplayer_authority():
		handle_movement()
		if Network.online:
			_net_sync.rpc(global_position)
	else:
		# Remote copy: only derive the animation from the received movement.
		_remote_moving = global_position.distance_to(_last_pos) > 0.1
		_last_pos = global_position
		velocity = Vector2.ONE if _remote_moving else Vector2.ZERO
	update_animation()


@rpc("authority", "unreliable")
func _net_sync(pos: Vector2) -> void:
	global_position = pos


func handle_movement() -> void:
	if not input_enabled or is_dying or is_dead:
		velocity = Vector2.ZERO
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
	buzz.stop()


func _on_animation_finished() -> void:
	if mosquito_sprite.animation == "die":
		is_dying = false
		is_dead = true

		mosquito_sprite.play("dead")


func set_boosted(boosted: bool) -> void:
	is_boosted = boosted
	if buzz != null:
		buzz.pitch_scale = 1.3 if boosted else 1.0


# Bite animation (called ONLY when a bite is really performed): lunge toward the target.
func play_bite_animation(target_pos: Vector2) -> void:
	if is_dying or is_dead:
		return
	var dir: Vector2 = (target_pos - global_position).normalized()
	if _sprite_tween != null:
		_sprite_tween.kill()
	mosquito_sprite.position = Vector2.ZERO
	mosquito_sprite.scale = Vector2.ONE
	_sprite_tween = create_tween()
	_sprite_tween.set_parallel(true)
	_sprite_tween.tween_property(mosquito_sprite, "position", dir * 14.0, 0.07)
	_sprite_tween.tween_property(mosquito_sprite, "scale", Vector2(1.5, 1.5), 0.07)
	_sprite_tween.chain().set_parallel(true)
	_sprite_tween.tween_property(mosquito_sprite, "position", Vector2.ZERO, 0.16)
	_sprite_tween.tween_property(mosquito_sprite, "scale", Vector2.ONE, 0.16)
	
func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
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
		
func can_bite_target(target: Node2D) -> bool:
	#print("\n--- BITE DEBUG ---")
#
	#print("Mosquito global position: ", global_position)
	#print("BiteArea global position: ", bite_area.global_position)
#
	#print("Human global position: ", target.global_position)
	return bite_area.overlaps_area(target.hurt_area)
