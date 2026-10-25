extends Node2D

const GameManager = preload("res://scripts/game_manager.gd")
var manager
@onready var human: Human = $Racket
@onready var mosquito: Mosquito = $Mosquito
@onready var hud: HUD = $HUD

enum TestPlayer {
	HUMAN,
	MOSQUITO
}
@export var test_player = TestPlayer.MOSQUITO

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	manager = GameManager.new()
	connect_game_signals()
	
	add_child(manager)
	connect_player_signals()
	setup_test_player()

func setup_test_player() -> void:
	match test_player:
		TestPlayer.HUMAN:
			human.set_input_enabled(true)
			mosquito.set_input_enabled(false)
			$CanvasModulate.visible=true
			human.set_vision_enabled(true)
		TestPlayer.MOSQUITO:
			human.set_input_enabled(false)
			mosquito.set_input_enabled(true)
			$CanvasModulate.visible=false
			human.set_vision_enabled(false)
		#TestPlayer.BOTH:
			#human.set_input_enabled(true)
			#mosquito.set_input_enabled(true)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	#print(
		#"Game: ", global_position,
		#" | Human: ", human.slap_area.global_position,
		#" | Mosquito: ", mosquito.global_position
	#)
	

func connect_player_signals() -> void:
	human.slap_requested.connect(
		_on_human_slap_requested
	)

	# Add this once mosquito.gd exposes bite_requested:
	mosquito.bite_requested.connect(
		_on_mosquito_bite_requested
	 )

func connect_game_signals() -> void:
	print("Connecting signals")
	manager.match_started.connect(
		_on_match_started
	)
	manager.match_ended.connect(_on_match_ended)
	manager.human_hp_changed.connect(_on_human_hp_changed)
	manager.human_stunned.connect(_on_human_stunned)
	manager.human_recovered.connect(_on_human_recovered)
	manager.mosquito_boost_started.connect(_on_mosquito_boost_started)
	manager.mosquito_boost_ended.connect(_on_mosquito_boost_ended)
	manager.slap_resolved.connect(
		_on_slap_resolved
	)
	
func _on_match_started(duration: float) -> void:
	print("Match started")
	print("Duration: ", duration)
	
func _on_human_slap_requested() -> void:
	# Temporary until collision detection is integrated.
	var did_hit := human.can_hit_target(mosquito)
	print("GAME: Human attempted to slap and succeeded? : ", did_hit)
	manager.attempt_slap(did_hit)
	
func _on_human_hp_changed(current: int, max_hp: int) -> void :
	#hud.set_human_hp(current, max_hp)
	human.set_hp_display(current)

func _on_human_stunned(duration: float) -> void:
	human.set_stunned(true)
	print("Human stunned for ", duration, " seconds")
	
func _on_human_recovered() -> void:
	human.set_stunned(false)
	print("Human recovered")
	
func _on_mosquito_boost_started(duration: float) -> void:
	mosquito.set_boosted(true)
	print("Mosquito boosted for ", duration, " seconds")

func _on_mosquito_boost_ended() -> void:
	mosquito.set_boosted(false)
	print("Mosquito boost ended")

func _on_match_ended(winner: int, _reason: int) -> void:
	print("Match ended. Winner ", winner)
	
func _on_slap_resolved(hit: bool) -> void:
	if hit:
		human.play_hit_animation()
		mosquito.die()
	else:
		human.play_hitting_animation()
	
func _on_mosquito_bite_requested() -> void:
	var did_hit := mosquito.can_bite_target(human)
	print("GAME: Mosquito attempted to bite..")
	manager.attempt_bite(did_hit)


#func _unhandled_key_input(event: InputEvent) -> void:
	#if not event.pressed:
		#return
	#if event.echo:
		#return
	#match event.keycode:
		#KEY_1:
			#print("Simulating sucessful bite")
			#manager.attempt_bite(true)
		#KEY_2:
			#print("Simulating missed slap")
			#manager.attempt_slap(false)
		#KEY_3:
			#print("Simulating successful slap")
			#manager.attempt_slap(true)
