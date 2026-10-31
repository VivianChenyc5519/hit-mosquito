extends Control
# Main page: title + host/join + Play button (enabled for the host once a 2nd player is connected).

var status_label: Label
var play_button: Button
var host_button: Button
var join_button: Button
var ip_edit: LineEdit


func _ready() -> void:
	_build_ui()
	Network.players_changed.connect(_on_players_changed)
	Network.join_failed.connect(_on_join_failed)
	Network.connection_lost.connect(_on_connection_lost)
	# If we come back from a game, make sure we start clean.
	if Network.online:
		Network.leave()
	_refresh()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(320, 0)
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := Label.new()
	title.text = "Hit That Moustique !"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	box.add_child(title)

	ip_edit = LineEdit.new()
	ip_edit.text = "127.0.0.1"
	ip_edit.placeholder_text = "Host IP address"
	box.add_child(ip_edit)

	host_button = Button.new()
	host_button.text = "Host game (you are the Human)"
	host_button.pressed.connect(_on_host_pressed)
	box.add_child(host_button)

	join_button = Button.new()
	join_button.text = "Join game (you are the Moustique)"
	join_button.pressed.connect(_on_join_pressed)
	box.add_child(join_button)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(status_label)

	play_button = Button.new()
	play_button.text = "PLAY"
	play_button.disabled = true
	play_button.pressed.connect(_on_play_pressed)
	box.add_child(play_button)

	# --- Solo debug mode (no network needed) ---
	var sep := HSeparator.new()
	box.add_child(sep)
	var dbg_label := Label.new()
	dbg_label.text = "Debug (solo, in-game press TAB to swap role)"
	dbg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(dbg_label)
	var dbg_human := Button.new()
	dbg_human.text = "Debug: play as Human"
	dbg_human.pressed.connect(func(): Network.start_debug("human"))
	box.add_child(dbg_human)
	var dbg_mosq := Button.new()
	dbg_mosq.text = "Debug: play as Moustique"
	dbg_mosq.pressed.connect(func(): Network.start_debug("mosquito"))
	box.add_child(dbg_mosq)


func _on_host_pressed() -> void:
	var err := Network.host_game()
	if err != OK:
		status_label.text = "Could not host (error %d). Is port %d already used?" % [err, Network.PORT]
		return
	_refresh()


func _on_join_pressed() -> void:
	var err := Network.join_game(ip_edit.text.strip_edges())
	if err != OK:
		status_label.text = "Could not connect (error %d)." % err
		return
	status_label.text = "Connecting..."
	host_button.disabled = true
	join_button.disabled = true


func _on_play_pressed() -> void:
	Network.start_game()


func _on_players_changed(_count: int) -> void:
	_refresh()


func _on_join_failed() -> void:
	status_label.text = "Connection failed (server full or unreachable)."
	_refresh()


func _on_connection_lost() -> void:
	status_label.text = "Connection lost."
	_refresh()


func _refresh() -> void:
	var connected := Network.online
	host_button.disabled = connected
	join_button.disabled = connected
	ip_edit.editable = not connected

	if not connected:
		play_button.disabled = true
		play_button.text = "PLAY"
		return

	var count := Network.player_count
	if Network.is_host():
		status_label.text = "Players: %d / %d" % [count, Network.MAX_PLAYERS]
		play_button.disabled = count < Network.MAX_PLAYERS
		play_button.text = "PLAY" if count == Network.MAX_PLAYERS else "Waiting for a second player..."
	else:
		status_label.text = "Connected. Players: %d / %d" % [count, Network.MAX_PLAYERS]
		play_button.disabled = true
		play_button.text = "Waiting for the host to press Play..."
