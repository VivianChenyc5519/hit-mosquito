extends Node2D

const GameManager = preload("res://scripts/game_manager.gd")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var manager = GameManager.new()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func connect_game_signals() -> void:
	manager.match_started.connect(
	)
	
function _on_match_started(duration: float) -> void:
	print("Match started")
	print("Duration: ", duration)
	
func _on_human_hp_changed(current: int, max: int) -> void :
	print("Human hp: ", current, "/", max)

func _on_human_stunned(duration: float) -> void
