extends Node2D
# Game scene. The HOST (peer 1) is the Human and runs the rules (GameManager).
# The CLIENT is the Mosquito. Clients send requests; the host resolves and broadcasts results.

const GameManager = preload("res://scripts/game_manager.gd")
const HumanSensor = preload("res://scripts/human_sensor.gd")
const START_DELAY := 1.0  # lets both peers finish loading the scene before the match starts

var manager
@onready var human: Human = $Racket
@onready var mosquito: Mosquito = $Mosquito

enum TestPlayer { HUMAN, MOSQUITO }
# Only used when you run this scene directly (no network) for debugging.
@export var test_player: TestPlayer = TestPlayer.HUMAN

var time_left: float = 0.0
var match_running: bool = false
var timer_label: Label
var end_layer: CanvasLayer
var end_label: Label
var debug_label: Label
var sensor_node: HumanSensor
var debug_as_human: bool = true


func _ready() -> void:
	_build_overlay()
	_build_boundaries()
	# Spawn points (the mosquito used to start at 0,0 = inside the wall).
	human.global_position = Vector2(100, 100)
	mosquito.global_position = Vector2(540, 280)

	if Network.online:
		# Host owns the human, the joining player owns the mosquito.
		human.set_multiplayer_authority(1)
		mosquito.set_multiplayer_authority(Network.mosquito_id)
		Network.connection_lost.connect(_on_connection_lost)
		if multiplayer.is_server():
			_setup_role(true)
			human.slap_requested.connect(_on_human_slap_requested)
			_start_host_match()
		else:
			_setup_role(false)
			mosquito.bite_requested.connect(_on_mosquito_bite_requested)
	else:
		# Offline debug mode: both characters exist, one keyboard.
		human.slap_requested.connect(_on_human_slap_requested)
		mosquito.bite_requested.connect(_on_mosquito_bite_requested)
		var as_human: bool = (test_player == TestPlayer.HUMAN)
		if Network.debug_role != "":
			as_human = Network.debug_role == "human"
		_setup_role(as_human)
		_start_host_match()
		debug_label.text = "DEBUG MODE - TAB: swap role | R: restart"
		debug_label.visible = true


func _build_boundaries() -> void:
	# The room is 40x24 tiles of 16px; the outer ring of tiles is the wall.
	# The "Walls" node has no collision shapes, so players could walk out of the room.
	var inner := Rect2(16, 16, 608, 352)
	var thick := 64.0
	var body := StaticBody2D.new()
	body.name = "RoomBounds"
	var rects: Array[Rect2] = [
		Rect2(inner.position.x - thick, inner.position.y - thick, inner.size.x + 2 * thick, thick),  # top
		Rect2(inner.position.x - thick, inner.end.y, inner.size.x + 2 * thick, thick),               # bottom
		Rect2(inner.position.x - thick, inner.position.y, thick, inner.size.y),                      # left
		Rect2(inner.end.x, inner.position.y, thick, inner.size.y),                                   # right
	]
	for r in rects:
		var shape := RectangleShape2D.new()
		shape.size = r.size
		var cs := CollisionShape2D.new()
		cs.shape = shape
		cs.position = r.position + r.size / 2.0
		body.add_child(cs)
	add_child(body)


func _setup_role(is_human: bool) -> void:
	human.set_input_enabled(is_human)
	mosquito.set_input_enabled(not is_human)
	var modulate_node: CanvasModulate = get_node_or_null("CanvasModulate")
	if modulate_node == null:
		modulate_node = CanvasModulate.new()
		modulate_node.name = "CanvasModulate"
		modulate_node.color = Color(0.03, 0.03, 0.05)
		add_child(modulate_node)
	modulate_node.visible = is_human  # human sees only a cone, mosquito sees everything
	human.set_vision_enabled(is_human)

	if sensor_node:
		sensor_node.queue_free()
		sensor_node = null
	if not is_human:
		# The mosquito senses the human as a red flickering dot.
		sensor_node = HumanSensor.new()
		sensor_node.target = human
		add_child(sensor_node)


func _start_host_match() -> void:
	await get_tree().create_timer(START_DELAY).timeout
	manager = GameManager.new()
	manager.match_started.connect(_on_match_started)
	manager.match_ended.connect(_on_match_ended)
	manager.human_hp_changed.connect(_on_human_hp_changed)
	manager.human_stunned.connect(_on_human_stunned)
	manager.human_recovered.connect(_on_human_recovered)
	manager.mosquito_boost_started.connect(_on_mosquito_boost_started)
	manager.mosquito_boost_ended.connect(_on_mosquito_boost_ended)
	manager.slap_resolved.connect(_on_slap_resolved)
	add_child(manager)  # _ready of the manager starts the match


func _unhandled_key_input(event: InputEvent) -> void:
	# Debug-only shortcuts (offline mode).
	var key := event as InputEventKey
	if Network.online or key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_TAB:
		var currently_human := human.input_enabled
		_setup_role(not currently_human)
	elif key.keycode == KEY_R:
		get_tree().reload_current_scene()


func _process(delta: float) -> void:
	if match_running:
		time_left = maxf(time_left - delta, 0.0)
	timer_label.text = "%d" % ceili(time_left)


# ---------------- requests (host side resolution) ----------------

func _on_human_slap_requested() -> void:
	if manager == null:
		return
	var did_hit: bool = human.can_hit_target(mosquito)
	manager.attempt_slap(did_hit)


func _on_mosquito_bite_requested() -> void:
	if Network.online and not multiplayer.is_server():
		_server_bite.rpc_id(1)
	else:
		_resolve_bite()


@rpc("any_peer", "reliable")
func _server_bite() -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != Network.mosquito_id:
		return
	_resolve_bite()


func _resolve_bite() -> void:
	if manager == null:
		return
	var did_hit: bool = mosquito.can_bite_target(human)
	manager.attempt_bite(did_hit)


# ---------------- manager signals (host only) -> broadcast ----------------

func _on_match_started(duration: float) -> void:
	if Network.online:
		_rpc_match_started.rpc(duration)
	else:
		_rpc_match_started(duration)


func _on_human_hp_changed(current: int, _max_hp: int) -> void:
	if Network.online:
		_rpc_hp.rpc(current)
	else:
		_rpc_hp(current)


func _on_human_stunned(_duration: float) -> void:
	if Network.online:
		_rpc_stun.rpc(true)
	else:
		_rpc_stun(true)


func _on_human_recovered() -> void:
	if Network.online:
		_rpc_stun.rpc(false)
	else:
		_rpc_stun(false)


func _on_mosquito_boost_started(_duration: float) -> void:
	# A successful bite also starts the bite cooldown.
	if Network.online:
		_rpc_boost.rpc(true)
		_rpc_bite_cd.rpc(manager.bite_cooldown)
	else:
		_rpc_boost(true)
		_rpc_bite_cd(manager.bite_cooldown)


func _on_mosquito_boost_ended() -> void:
	if Network.online:
		_rpc_boost.rpc(false)
	else:
		_rpc_boost(false)


func _on_slap_resolved(hit: bool) -> void:
	if Network.online:
		_rpc_slap.rpc(hit)
	else:
		_rpc_slap(hit)


func _on_match_ended(winner: int, reason: int) -> void:
	if Network.online:
		_rpc_end.rpc(winner, reason)
	else:
		_rpc_end(winner, reason)


# ---------------- replicated effects (run on every peer) ----------------

@rpc("authority", "call_local", "reliable")
func _rpc_match_started(duration: float) -> void:
	time_left = duration
	match_running = true


@rpc("authority", "call_local", "reliable")
func _rpc_hp(current: int) -> void:
	human.set_hp_display(current)


@rpc("authority", "call_local", "reliable")
func _rpc_stun(stunned: bool) -> void:
	human.set_stunned(stunned)


@rpc("authority", "call_local", "reliable")
func _rpc_boost(boosted: bool) -> void:
	mosquito.set_boosted(boosted)


@rpc("authority", "call_local", "reliable")
func _rpc_bite_cd(duration: float) -> void:
	mosquito.start_cooldown(duration)


@rpc("authority", "call_local", "reliable")
func _rpc_slap(hit: bool) -> void:
	human.start_cooldown(manager.slap_cooldown if manager else 0.5)
	if hit:
		human.play_hit_animation()
		mosquito.die()
	else:
		human.play_hitting_animation()


@rpc("authority", "call_local", "reliable")
func _rpc_end(winner: int, reason: int) -> void:
	match_running = false
	human.set_input_enabled(false)
	mosquito.set_input_enabled(false)

	var i_am_human := (not Network.online) or multiplayer.is_server()
	var human_won := winner == 1  # GameManager.Winner.HUMAN
	var text := ""
	if human_won == i_am_human:
		text = "YOU WIN!"
	else:
		text = "YOU LOSE"
	match reason:
		1: text += "\nThe moustique was squashed."
		2: text += "\nThe human lost all their HP."
		3: text += "\nTime is up, the moustique escaped."
	end_label.text = text
	end_layer.visible = true


# ---------------- UI ----------------

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	timer_label = Label.new()
	timer_label.position = Vector2(20, 10)
	timer_label.add_theme_font_size_override("font_size", 28)
	layer.add_child(timer_label)

	debug_label = Label.new()
	debug_label.position = Vector2(20, 50)
	debug_label.modulate = Color(1, 1, 0.4)
	debug_label.visible = false
	layer.add_child(debug_label)

	end_layer = CanvasLayer.new()
	end_layer.visible = false
	end_layer.layer = 20
	add_child(end_layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_layer.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	center.add_child(box)

	end_label = Label.new()
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.add_theme_font_size_override("font_size", 40)
	box.add_child(end_label)

	var back := Button.new()
	back.text = "Back to lobby"
	back.pressed.connect(func(): Network.go_to_lobby())
	box.add_child(back)


func _on_connection_lost() -> void:
	match_running = false
	end_label.text = "The other player disconnected."
	end_layer.visible = true
