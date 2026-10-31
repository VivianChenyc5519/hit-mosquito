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
@onready var hurt_area: Area2D = $HurtArea
@onready var vision_light: PointLight2D = $RacketPivot/VisionLight
@onready var health_heart: Sprite2D = $HealthBar

@export var heart_full: Texture2D
@export var heart_75: Texture2D
@export var heart_50: Texture2D
@export var heart_25: Texture2D
@export var heart_dead: Texture2D

const CooldownRing = preload("res://scripts/cooldown_ring.gd")
var cooldown_ring: CooldownRing


func _ready() -> void:
	cooldown_ring = CooldownRing.new()
	cooldown_ring.position = Vector2(-3, 76)
	add_child(cooldown_ring)
	racket_sprite.play("idle")
	racket_sprite.animation_finished.connect(_on_racket_animation_finished)
	print("Heart node: ", health_heart)
	print("Full heart texture: ", heart_full)

	health_heart.texture = heart_full

	print("Heart texture after assignment: ", health_heart.texture)
	print("Heart visible: ", health_heart.visible)
	print("Heart position: ", health_heart.global_position)


var input_enabled := true
var is_stunned := false


func _physics_process(_delta: float) -> void:
	# Only the owner (the host) simulates the human; the other peer just receives its state.
	if not is_multiplayer_authority():
		return
	handle_movement()
	handle_aim(_delta)
	if Network.online:
		_net_sync.rpc(global_position, racket_pivot.rotation)


@rpc("authority", "unreliable")
func _net_sync(pos: Vector2, aim: float) -> void:
	global_position = pos
	racket_pivot.rotation = aim

func set_hp_display(current_hp: int) -> void:
	match current_hp:
		4:
			health_heart.texture = heart_full
		3:
			health_heart.texture = heart_75
		2:
			health_heart.texture = heart_50
		1:
			health_heart.texture = heart_25
		0:
			health_heart.texture = heart_dead

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
	if not is_multiplayer_authority():
		return
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

func start_cooldown(duration: float) -> void:
	cooldown_ring.start(duration)


func set_vision_enabled(enabled: bool) -> void:
	vision_light.enabled = enabled
	
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
