extends Node2D
# Game scene. The HOST (peer 1) is the Human and runs the rules (GameManager).
# The CLIENT is the Mosquito. Clients send requests; the host resolves and broadcasts results.
# Debug (solo) mode runs exactly the same code, just without a network.

const GameManager = preload("res://scripts/game_manager.gd")
const HumanSensor = preload("res://scripts/human_sensor.gd")
const MapWalls = preload("res://scripts/map_walls.gd")
const START_DELAY := 1.0  # lets both peers finish loading the scene before the match starts

# --- Map options (edit in the Inspector on the Game node) ---
# Builds collision walls automatically: every EMPTY cell of "TileMapLayer" (+ the outside of the map) is solid.
# Turn OFF if you place your own collision walls by hand.
@export var auto_wall_collision: bool = true
# How close the camera is to the action (1 = whole map visible, 2 = half of it).
@export var camera_zoom: float = 2.0
# Human view: very dark except the flashlight. Mosquito view: a bit darker, flashlight still visible.
@export var human_darkness: Color = Color(0.08, 0.05, 0.11, 1.0)
@export var mosquito_darkness: Color = Color(0.46, 0.38, 0.54, 1.0)
@export var human_wall_dim: Color = Color(0.5, 0.5, 0.55, 1.0)
@export var mosquito_wall_dim: Color = Color(0.9, 0.9, 0.95, 1.0)
# Where the players start (must be on the brown floor).
@export var human_spawn: Vector2 = Vector2(100, 100)
@export var mosquito_spawn: Vector2 = Vector2(540, 280)

enum TestPlayer { HUMAN, MOSQUITO }
# Only used when you run this scene directly (no network) for debugging.
@export var test_player: TestPlayer = TestPlayer.HUMAN

var manager
@onready var human: Human = $Racket
@onready var mosquito: Mosquito = $Mosquito

var ui: GameUI
var darkness: CanvasModulate
var cam: Camera2D
var map_walls: MapWalls
var map_rect: Rect2 = Rect2(0, 0, 640, 384)
var sensor_node: HumanSensor

var me_is_human: bool = true
var match_running: bool = false
var match_over: bool = false
var time_left: float = 0.0
var time_total: float = 120.0

# Replicated state used by the stats panels (updated on every peer by the RPCs below).
var human_hp: int = 4
var human_max_hp: int = 4
var mosquito_alive: bool = true
var slap_cd_end: int = 0
var slap_cd_total: float = 0.5
var bite_cd_end: int = 0
var bite_cd_total: float = 1.0
var stun_end: int = 0
var boost_end: int = 0


func _ready() -> void:
	darkness = get_node_or_null("CanvasModulate") as CanvasModulate
	if darkness == null:
		darkness = CanvasModulate.new()
		darkness.name = "CanvasModulate"
		add_child(darkness)

	ui = GameUI.new()
	add_child(ui)
	ui.back_to_lobby_pressed.connect(func(): Network.go_to_lobby())
	ui.play_again_pressed.connect(func(): get_tree().reload_current_scene())

	RenderingServer.set_default_clear_color(Color.BLACK)
	human.z_index = 5
	mosquito.z_index = 5
	_setup_map()
	_setup_camera()

	# Spawn points (the mosquito used to start at 0,0 = inside the wall).
	human.global_position = human_spawn
	mosquito.global_position = mosquito_spawn

	Sfx.play_music()

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
		# Offline debug mode: both characters exist, one keyboard. Same rules, same UI, same sounds.
		human.slap_requested.connect(_on_human_slap_requested)
		mosquito.bite_requested.connect(_on_mosquito_bite_requested)
		var as_human: bool = test_player == TestPlayer.HUMAN
		if Network.debug_role != "":
			as_human = Network.debug_role == "human"
		_setup_role(as_human)
		_start_host_match()
		ui.set_debug_text("DEBUG MODE\nTAB: swap role\nR: restart")


# ---------------------------------------------------------------- map

# The brown tiles are the FLOOR. Every empty cell (and everything outside) is a wall.
func _setup_map() -> void:
	var tm := get_node_or_null("TileMapLayer") as TileMapLayer
	if tm == null:
		return
	var tile: int = 16
	if tm.tile_set != null:
		tile = tm.tile_set.tile_size.x
	var used: Rect2i = tm.get_used_rect()
	map_rect = Rect2(Vector2(used.position) * tile, Vector2(used.size) * tile)

	var floor_lookup: Dictionary = {}
	for c in tm.get_used_cells():
		floor_lookup[c] = true
	var wall_cells: Array[Vector2i] = []
	for y in range(used.position.y, used.end.y):
		for x in range(used.position.x, used.end.x):
			if not floor_lookup.has(Vector2i(x, y)):
				wall_cells.append(Vector2i(x, y))

	# wall look (always visible, dimmed per role in _setup_role)
	map_walls = MapWalls.new()
	map_walls.name = "MapWalls"
	map_walls.tile = tile
	map_walls.wall_cells = wall_cells
	map_walls.floor_lookup = floor_lookup
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	map_walls.material = unshaded
	add_child(map_walls)
	move_child(map_walls, tm.get_index() + 1)

	if auto_wall_collision:
		_build_collision(wall_cells, floor_lookup, tile, used)


# One rectangle per horizontal run of wall cells + a thick frame around the map.
func _build_collision(wall_cells: Array[Vector2i], _floor_lookup: Dictionary, tile: int, used: Rect2i) -> void:
	var body := StaticBody2D.new()
	body.name = "MapCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	var is_wall: Dictionary = {}
	for c in wall_cells:
		is_wall[c] = true
	for y in range(used.position.y, used.end.y):
		var x: int = used.position.x
		while x < used.end.x:
			if is_wall.has(Vector2i(x, y)):
				var start: int = x
				while x < used.end.x and is_wall.has(Vector2i(x, y)):
					x += 1
				_add_rect(body, Rect2(start * tile, y * tile, (x - start) * tile, tile))
			else:
				x += 1
	var t := 128.0
	var r := map_rect
	_add_rect(body, Rect2(r.position.x - t, r.position.y - t, r.size.x + 2 * t, t))
	_add_rect(body, Rect2(r.position.x - t, r.end.y, r.size.x + 2 * t, t))
	_add_rect(body, Rect2(r.position.x - t, r.position.y, t, r.size.y))
	_add_rect(body, Rect2(r.end.x, r.position.y, t, r.size.y))
	add_child(body)


func _add_rect(body: StaticBody2D, r: Rect2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = r.size
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = r.position + r.size / 2.0
	body.add_child(cs)


# Camera: follows MY character and stops at the map edges (screen = 800x384, arena part = 640 wide).
func _setup_camera() -> void:
	cam = Camera2D.new()
	cam.zoom = Vector2(camera_zoom, camera_zoom)
	cam.offset = Vector2(80.0 / camera_zoom, 0.0)  # keeps the player centred in the arena part (left 640 px)
	# (Camera limits are applied before the offset, so the offset is subtracted here.)
	cam.limit_left = int(map_rect.position.x - cam.offset.x)
	cam.limit_top = int(map_rect.position.y)
	cam.limit_right = int(map_rect.end.x + 160.0 / camera_zoom - cam.offset.x)
	cam.limit_bottom = int(map_rect.end.y)
	cam.position_smoothing_enabled = false
	add_child(cam)
	cam.make_current()


# ---------------------------------------------------------------- roles / vision

func _setup_role(is_human: bool) -> void:
	me_is_human = is_human
	human.set_input_enabled(is_human)
	mosquito.set_input_enabled(not is_human)

	# Human: map almost black, only the flashlight shows the floor, mosquito only visible in the beam.
	# Mosquito: map a bit darker, and it still sees where the human's flashlight is pointing.
	darkness.color = human_darkness if is_human else mosquito_darkness
	darkness.visible = not match_over
	human.set_vision_enabled(true)  # the beam exists for both players
	if map_walls != null:
		map_walls.modulate = human_wall_dim if is_human else mosquito_wall_dim
	# the mosquito always sees itself
	var mat: CanvasItemMaterial = null
	if not is_human:
		mat = CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	mosquito.mosquito_sprite.material = mat

	# Ears: the human hears the buzz get louder when it gets closer.
	if is_human:
		human.listener.make_current()
		mosquito.buzz.volume_db = 0.0
	else:
		mosquito.listener.make_current()
		mosquito.buzz.volume_db = -14.0

	if sensor_node:
		sensor_node.queue_free()
		sensor_node = null
	if not is_human:
		# The mosquito senses the human as a red flickering dot.
		sensor_node = HumanSensor.new()
		sensor_node.target = human
		add_child(sensor_node)

	ui.set_roles(is_human)


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
	manager.bite_resolved.connect(_on_bite_resolved)
	add_child(manager)  # _ready of the manager starts the match


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_M:
		Sfx.toggle_music()
		return
	# Debug-only shortcuts (offline mode).
	if Network.online:
		return
	if key.keycode == KEY_TAB and not match_over:
		_setup_role(not human.input_enabled)
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_R:
		get_tree().reload_current_scene()


func _process(delta: float) -> void:
	if match_running:
		time_left = maxf(time_left - delta, 0.0)
	ui.set_time(time_left, time_total)

	# Camera follows the character I control.
	if cam != null:
		var target: Node2D = human if me_is_human else mosquito
		cam.global_position = target.global_position

	# The human only sees the mosquito while it is inside the flashlight beam.
	if me_is_human and not match_over:
		mosquito.visible = human.is_lit(mosquito.global_position, 10.0)
	else:
		mosquito.visible = true

	var now := Time.get_ticks_msec()
	ui.set_human_stats(human_hp, human_max_hp,
		_fraction(slap_cd_end, slap_cd_total, now), maxf((stun_end - now) / 1000.0, 0.0))
	ui.set_mosquito_stats(mosquito_alive,
		_fraction(bite_cd_end, bite_cd_total, now), maxf((boost_end - now) / 1000.0, 0.0))


func _fraction(end_msec: int, total: float, now: int) -> float:
	if now >= end_msec or total <= 0.0:
		return 1.0
	return clampf(1.0 - ((end_msec - now) / 1000.0) / total, 0.0, 1.0)


# ---------------------------------------------------------------- requests (host side resolution)

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


# ---------------------------------------------------------------- manager signals (host only) -> broadcast

func _on_match_started(duration: float) -> void:
	if Network.online:
		_rpc_match_started.rpc(duration)
	else:
		_rpc_match_started(duration)


func _on_human_hp_changed(current: int, max_hp: int) -> void:
	if Network.online:
		_rpc_hp.rpc(current, max_hp)
	else:
		_rpc_hp(current, max_hp)


func _on_human_stunned(duration: float) -> void:
	if Network.online:
		_rpc_stun.rpc(true, duration)
	else:
		_rpc_stun(true, duration)


func _on_human_recovered() -> void:
	if Network.online:
		_rpc_stun.rpc(false, 0.0)
	else:
		_rpc_stun(false, 0.0)


func _on_mosquito_boost_started(duration: float) -> void:
	# A successful bite also starts the (long) bite cooldown.
	var cd: float = manager.bite_cooldown
	if Network.online:
		_rpc_boost.rpc(true, duration)
		_rpc_bite_cd.rpc(cd)
	else:
		_rpc_boost(true, duration)
		_rpc_bite_cd(cd)


func _on_mosquito_boost_ended() -> void:
	if Network.online:
		_rpc_boost.rpc(false, 0.0)
	else:
		_rpc_boost(false, 0.0)


func _on_slap_resolved(hit: bool) -> void:
	var cd: float = manager.slap_cooldown
	if Network.online:
		_rpc_slap.rpc(hit, cd)
	else:
		_rpc_slap(hit, cd)


func _on_bite_resolved(hit: bool) -> void:
	var miss_cd: float = manager.bite_miss_cooldown
	if Network.online:
		_rpc_bite.rpc(hit, miss_cd)
	else:
		_rpc_bite(hit, miss_cd)


func _on_match_ended(winner: int, reason: int) -> void:
	if Network.online:
		_rpc_end.rpc(winner, reason)
	else:
		_rpc_end(winner, reason)


# ---------------------------------------------------------------- replicated effects (run on every peer)

@rpc("authority", "call_local", "reliable")
func _rpc_match_started(duration: float) -> void:
	time_left = duration
	time_total = duration
	match_running = true
	ui.toast("HUNT!", UiTheme.COL_ACCENT)


@rpc("authority", "call_local", "reliable")
func _rpc_hp(current: int, max_hp: int) -> void:
	human_hp = current
	human_max_hp = max_hp
	human.set_hp_display(current)


@rpc("authority", "call_local", "reliable")
func _rpc_stun(stunned: bool, duration: float) -> void:
	human.set_stunned(stunned)
	stun_end = Time.get_ticks_msec() + int(duration * 1000.0) if stunned else 0


@rpc("authority", "call_local", "reliable")
func _rpc_boost(boosted: bool, duration: float) -> void:
	mosquito.set_boosted(boosted)
	boost_end = Time.get_ticks_msec() + int(duration * 1000.0) if boosted else 0


@rpc("authority", "call_local", "reliable")
func _rpc_bite_cd(duration: float) -> void:
	bite_cd_total = duration
	bite_cd_end = Time.get_ticks_msec() + int(duration * 1000.0)
	mosquito.start_cooldown(duration)


# The mosquito really bit (hit or miss): lunge animation, sound, damage feedback.
@rpc("authority", "call_local", "reliable")
func _rpc_bite(hit: bool, miss_cooldown: float) -> void:
	mosquito.play_bite_animation(human.global_position)
	if hit:
		Sfx.bite()
		human.play_hurt()
		ui.toast("BITTEN!  -1 HP", UiTheme.COL_DANGER)
		if me_is_human:
			ui.flash(Color(1.0, 0.2, 0.4))
	else:
		# Missed bite: short cooldown so it can't be spammed.
		bite_cd_total = miss_cooldown
		bite_cd_end = Time.get_ticks_msec() + int(miss_cooldown * 1000.0)
		mosquito.start_cooldown(miss_cooldown)


# The human really swung the racket (only when he clicked and was allowed to).
@rpc("authority", "call_local", "reliable")
func _rpc_slap(hit: bool, cooldown: float) -> void:
	slap_cd_total = cooldown
	slap_cd_end = Time.get_ticks_msec() + int(cooldown * 1000.0)
	human.start_cooldown(cooldown)
	if hit:
		Sfx.zap()
		human.play_hit_animation()
		mosquito_alive = false
		mosquito.die()
		ui.toast("ZAP!", UiTheme.COL_ACCENT)
		if not me_is_human:
			ui.flash(Color(0.97, 0.94, 0.75))
	else:
		Sfx.woosh()
		human.play_hitting_animation()


@rpc("authority", "call_local", "reliable")
func _rpc_end(winner: int, reason: int) -> void:
	match_running = false
	match_over = true
	human.set_input_enabled(false)
	mosquito.set_input_enabled(false)
	darkness.visible = false  # lights on: everybody sees everything
	if map_walls != null:
		map_walls.modulate = Color.WHITE
	mosquito.visible = true
	if mosquito.buzz != null:
		mosquito.buzz.stop()

	var human_won: bool = winner == 1  # GameManager.Winner.HUMAN
	var won: bool = human_won == me_is_human
	var text := ""
	match reason:
		1:
			text = "The mosquito was zapped by the racket." if me_is_human else "You got zapped by the racket."
		2:
			text = "The mosquito drained all your HP." if me_is_human else "You drained all the human's HP!"
		3:
			text = "Time is up: the mosquito escaped." if me_is_human else "Time is up: you survived!"
	ui.show_end("VICTORY!" if won else "DEFEAT", text, won, not Network.online)


func _on_connection_lost() -> void:
	match_running = false
	match_over = true
	ui.show_end("DISCONNECTED", "The other player left the game.", false, false)
