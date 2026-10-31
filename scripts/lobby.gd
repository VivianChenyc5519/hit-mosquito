extends Control
# Main page: title + "how to play" window + connection window + solo debug window.
# The Play button is enabled for the host once a 2nd player is connected.

var status_label: Label
var play_button: Button
var host_button: Button
var join_button: Button
var ip_edit: LineEdit
var music_button: Button
var credits_window: Control


func _ready() -> void:
	theme = UiTheme.make()
	Sfx.play_music()
	_build_ui()
	Network.players_changed.connect(_on_players_changed)
	Network.join_failed.connect(_on_join_failed)
	Network.connection_lost.connect(_on_connection_lost)
	# If we come back from a game, make sure we start clean.
	if Network.online:
		Network.leave()
	_refresh()


func _window(title: String, color: Color = UiTheme.COL_BORDER) -> VBoxContainer:
	# A "mini window": bordered panel with a coloured title.
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.COL_PANEL, color, 2, 10, 8))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	var t := Label.new()
	t.text = title
	t.add_theme_color_override("font_color", color if color != UiTheme.COL_BORDER else UiTheme.COL_ACCENT)
	t.add_theme_font_override("font", UiTheme.font(true))
	v.add_child(t)
	var sep := HSeparator.new()
	v.add_child(sep)
	# the caller adds the panel through v.get_parent()
	return v


func _text(parent: Control, text: String, color: Color = UiTheme.COL_TEXT, size: int = 11) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(1, 0)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	parent.add_child(l)
	return l


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("120b1c")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# faint floor tiles as a background
	var floor_tex := TextureRect.new()
	floor_tex.texture = load("res://assets/tile.png") as Texture2D
	floor_tex.stretch_mode = TextureRect.STRETCH_TILE
	floor_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	floor_tex.modulate = Color(1, 1, 1, 0.12)
	floor_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(floor_tex)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	center.add_child(root)

	# --- title ---
	var title := Label.new()
	title.text = "HIT THAT MOUSTIQUE !"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_font_override("font", UiTheme.font(true))
	title.add_theme_color_override("font_color", UiTheme.COL_ACCENT)
	title.add_theme_color_override("font_outline_color", Color("40104a"))
	title.add_theme_constant_override("outline_size", 8)
	root.add_child(title)
	var sub := Label.new()
	sub.text = "a 2-player hunt in the dark"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", UiTheme.COL_DIM)
	root.add_child(sub)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	root.add_child(row)

	# --- how to play window ---
	var how := _window("HOW TO PLAY")
	how.get_parent().custom_minimum_size = Vector2(300, 0)
	row.add_child(how.get_parent())
	_text(how, "HUMAN  (host)", UiTheme.COL_HUMAN, 12)
	_text(how, "Electric racket + flashlight. You only see what the light shows. Mouse = aim, click = ZAP. One hit kills the mosquito, but a bite costs 1 of your 4 HP and stuns you.", UiTheme.COL_TEXT, 10)
	_text(how, "MOSQUITO  (joins)", UiTheme.COL_MOSQUITO, 12)
	_text(how, "You see the whole room and feel the human as a red dot. Click to bite. A bite gives you a speed boost. Survive until the timer ends!", UiTheme.COL_TEXT, 10)

	# --- connection window ---
	var net := _window("PLAY ONLINE")
	net.get_parent().custom_minimum_size = Vector2(300, 0)
	row.add_child(net.get_parent())

	ip_edit = LineEdit.new()
	ip_edit.text = "127.0.0.1"
	ip_edit.placeholder_text = "Host IP address"
	net.add_child(ip_edit)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	net.add_child(buttons)
	host_button = Button.new()
	host_button.text = "Host (Human)"
	host_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host_button.pressed.connect(_on_host_pressed)
	buttons.add_child(host_button)
	join_button = Button.new()
	join_button.text = "Join (Mosquito)"
	join_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_button.pressed.connect(_on_join_pressed)
	buttons.add_child(join_button)

	status_label = _text(net, "", UiTheme.COL_DIM, 11)
	status_label.custom_minimum_size = Vector2(1, 30)

	play_button = Button.new()
	play_button.text = "PLAY"
	play_button.disabled = true
	play_button.custom_minimum_size = Vector2(0, 30)
	play_button.add_theme_font_size_override("font_size", 16)
	play_button.pressed.connect(_on_play_pressed)
	net.add_child(play_button)

	# --- solo debug window ---
	var dbg := _window("SOLO TEST  (no network)", Color("8a6aa8"))
	root.add_child(dbg.get_parent())
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 6)
	dbg.add_child(drow)
	var dbg_human := Button.new()
	dbg_human.text = "Test as Human"
	dbg_human.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dbg_human.pressed.connect(func(): Network.start_debug("human"))
	drow.add_child(dbg_human)
	var dbg_mosq := Button.new()
	dbg_mosq.text = "Test as Mosquito"
	dbg_mosq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dbg_mosq.pressed.connect(func(): Network.start_debug("mosquito"))
	drow.add_child(dbg_mosq)
	_text(dbg, "Same game as online. In game: TAB swaps role, R restarts, M toggles music.", UiTheme.COL_DIM, 10)

	# --- always-visible music + credits buttons (top corners) ---
	music_button = Button.new()
	music_button.focus_mode = Control.FOCUS_NONE
	music_button.position = Vector2(8, 8)
	music_button.pressed.connect(func(): Sfx.toggle_music())
	add_child(music_button)
	Sfx.music_changed.connect(_on_music_changed)
	_on_music_changed(Sfx.music_enabled)

	var credits_button := Button.new()
	credits_button.text = "Credits"
	credits_button.focus_mode = Control.FOCUS_NONE
	credits_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	credits_button.offset_left = -80
	credits_button.offset_top = 8
	credits_button.offset_right = -8
	credits_button.pressed.connect(func(): credits_window.visible = true)
	add_child(credits_button)
	_build_credits()


func _build_credits() -> void:
	credits_window = Control.new()
	credits_window.set_anchors_preset(Control.PRESET_FULL_RECT)
	credits_window.visible = false
	add_child(credits_window)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	credits_window.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	credits_window.add_child(center)
	var win := _window("CREDITS", UiTheme.COL_ACCENT)
	win.get_parent().custom_minimum_size = Vector2(380, 0)
	center.add_child(win.get_parent())
	var big := _text(win, "Game created by IGD students\nVivian (M2) and Lou-Ann (M1)", UiTheme.COL_TEXT, 14)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _text(win, "It was Vivian's idea and plan.\nLou-Ann designed all the assets.\nWe both implemented the game together!", UiTheme.COL_DIM, 11)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func(): credits_window.visible = false)
	win.add_child(close)


func _on_music_changed(enabled: bool) -> void:
	if music_button != null:
		music_button.text = "Music: ON  (M)" if enabled else "Music: OFF (M)"


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_M and not ip_edit.has_focus():
		Sfx.toggle_music()


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
		play_button.text = "PLAY" if count == Network.MAX_PLAYERS else "Waiting for a 2nd player..."
	else:
		status_label.text = "Connected. Players: %d / %d" % [count, Network.MAX_PLAYERS]
		play_button.disabled = true
		play_button.text = "Waiting for the host..."
