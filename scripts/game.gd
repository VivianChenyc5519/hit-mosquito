extends Node2D

const GameManager = preload("res://scripts/game_manager.gd")
var manager


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	manager = GameManager.new()
	add_child(manager)
	connect_game_signals()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func connect_game_signals() -> void:
	manager.match_started.connect(
		_on_match_started
	)
	manager.match_ended.connect(_on_match_ended)
	manager.human_hp_changed.connect(_on_human_hp_changed)
	manager.human_stunned.connect(_on_human_stunned)
	manager.human_recovered.connect(_on_human_recovered)
	manager.mosquito_boost_started.connect(_on_mosquito_boost_started)
	manager.mosquito_boost_ended.connect(_on_mosquito_boost_ended)
	
func _on_match_started(duration: float) -> void:
	print("Match started")
	print("Duration: ", duration)
	
func _on_human_hp_changed(current: int, max_hp: int) -> void :
	print("Human hp: ", current, "/", max_hp)

func _on_human_stunned(duration: float) -> void:
	print("Human stunned for ", duration, " seconds")
	
func _on_human_recovered() -> void:
	print("Human recovered")
	
func _on_mosquito_boost_started(duration: float) -> void:
	print("Mosquito boosted for ", duration, " seconds")

func _on_mosquito_boost_ended() -> void:
	print("Mosquito boost ended")

func _on_match_ended(winner: int, _reason: int) -> void:
	print("Match ended. Winner ", winner)
	
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed:
		return
	if event.echo:
		return
	match event.keycode:
		KEY_1:
			print("Simulating sucessful bite")
			manager.attempt_bite(true)
		KEY_2:
			print("Simulating missed slap")
			manager.attempt_slap(false)
		KEY_3:
			print("Simulating successful slap")
			manager.attempt_slap(true)
