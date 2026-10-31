class_name GameUI
extends CanvasLayer
# Everything you see on top of the game: right-hand side panel (timer, YOUR STATS, ENEMY STATS),
# toasts, damage flash and the end-of-match window. Built in code, same in debug and online mode.
#
# Screen is 800x384 "logical" pixels: the arena takes x = 0..640, this panel takes x = 640..800.

signal back_to_lobby_pressed
signal play_again_pressed

const ARENA_W := 640.0
const SCREEN_W := 800.0
const SCREEN_H := 384.0

const HEART_FULL := preload("res://assets/heart_full.png")
const HEART_75 := preload("res://assets/heart_75.png")
const HEART_50 := preload("res://assets/heart_50.png")
const HEART_25 := preload("res://assets/heart_25.png")
const HEART_0 := preload("res://assets/heart_0.png")


# ---------------------------------------------------------------- StatPanel (one "mini window")
class StatPanel extends PanelContainer:
	var role_color: Color = Color.WHITE
	var name_label: Label
	var heart: TextureRect
	var hp_label: Label
	var bar_caption: Label
	var bar: ProgressBar
	var status_label: Label
	var _fill: StyleBoxFlat

	func build(role_name: String, color: Color, caption: String) -> void:
		role_color = color
		var sb := UiTheme.box(UiTheme.COL_PANEL, color, 2, 6, 5)
		add_theme_stylebox_override("panel", sb)

		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 3)
		add_child(v)

		var title_row := HBoxContainer.new()
		v.add_child(title_row)
		name_label = Label.new()
		name_label.text = role_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_color_override("font_color", color)
		name_label.add_theme_font_override("font", UiTheme.font(true))
		title_row.add_child(name_label)
		status_label = Label.new()
		status_label.text = " "
		status_label.add_theme_font_size_override("font_size", 10)
		title_row.add_child(status_label)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		v.add_child(row)

		heart = TextureRect.new()
		heart.custom_minimum_size = Vector2(24, 24)
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(heart)

		hp_label = Label.new()
		hp_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(hp_label)

		bar_caption = Label.new()
		bar_caption.text = caption
		bar_caption.add_theme_color_override("font_color", UiTheme.COL_DIM)
		v.add_child(bar_caption)

		bar = ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.value = 1.0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 8)
		_fill = UiTheme.fill_box(color)
		bar.add_theme_stylebox_override("fill", _fill)
		v.add_child(bar)

	func set_heart(tex: Texture2D, text: String) -> void:
		heart.texture = tex
		hp_label.text = text

	func set_bar(ready_fraction: float, caption: String, ready: bool) -> void:
		bar.value = ready_fraction
		bar_caption.text = caption
		_fill.bg_color = UiTheme.COL_GOOD if ready else role_color
		_fill.border_color = _fill.bg_color

	func set_status(text: String, color: Color) -> void:
		status_label.text = text if text != "" else " "
		status_label.add_theme_color_override("font_color", color)


# ---------------------------------------------------------------- members
var human_panel: StatPanel
var mosquito_panel: StatPanel
var your_slot: VBoxContainer
var enemy_slot: VBoxContainer
var timer_label: Label
var timer_bar: ProgressBar
var controls_label: Label
var debug_label: Label
var music_button: Button
var toast_label: Label
var flash_rect: ColorRect
var end_root: Control
var end_title: Label
var end_reason: Label
var end_again: Button
var _toast_tween: Tween
var _flash_tween: Tween
var _root: Control
var _me_is_human: bool = true


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.theme = UiTheme.make()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_flash()
	_build_side_panel()
	_build_toast()
	_build_end_window()
	Sfx.music_changed.connect(_on_music_changed)
	_on_music_changed(Sfx.music_enabled)


func _build_flash() -> void:
	flash_rect = ColorRect.new()
	flash_rect.position = Vector2.ZERO
	flash_rect.size = Vector2(ARENA_W, SCREEN_H)
	flash_rect.color = Color(1, 0, 0, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(flash_rect)


func _build_side_panel() -> void:
	var bg := ColorRect.new()
	bg.color = Color("100a1a")
	bg.position = Vector2(ARENA_W, 0)
	bg.size = Vector2(SCREEN_W - ARENA_W, SCREEN_H)
	_root.add_child(bg)

	var edge := ColorRect.new()
	edge.color = UiTheme.COL_BORDER
	edge.position = Vector2(ARENA_W, 0)
	edge.size = Vector2(2, SCREEN_H)
	_root.add_child(edge)

	var margin := MarginContainer.new()
	margin.position = Vector2(ARENA_W + 2, 0)
	margin.size = Vector2(SCREEN_W - ARENA_W - 2, SCREEN_H)
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_root.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	margin.add_child(col)

	# --- timer window ---
	var timer_box := PanelContainer.new()
	col.add_child(timer_box)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 2)
	timer_box.add_child(tv)
	var tcap := Label.new()
	tcap.text = "TIME"
	tcap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tcap.add_theme_color_override("font_color", UiTheme.COL_DIM)
	tv.add_child(tcap)
	timer_label = Label.new()
	timer_label.text = "--"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 22)
	timer_label.add_theme_font_override("font", UiTheme.font(true))
	tv.add_child(timer_label)
	timer_bar = ProgressBar.new()
	timer_bar.max_value = 1.0
	timer_bar.value = 1.0
	timer_bar.show_percentage = false
	timer_bar.custom_minimum_size = Vector2(0, 6)
	tv.add_child(timer_bar)

	# --- YOUR STATS / ENEMY STATS ---
	your_slot = _make_slot("YOUR STATS", col)
	enemy_slot = _make_slot("ENEMY STATS", col)

	human_panel = StatPanel.new()
	human_panel.build("HUMAN", UiTheme.COL_HUMAN, "SLAP")
	mosquito_panel = StatPanel.new()
	mosquito_panel.build("MOSQUITO", UiTheme.COL_MOSQUITO, "BITE")

	# --- bottom: controls + music + debug ---
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	controls_label = Label.new()
	controls_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_label.add_theme_color_override("font_color", UiTheme.COL_DIM)
	controls_label.add_theme_font_size_override("font_size", 10)
	col.add_child(controls_label)

	debug_label = Label.new()
	debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	debug_label.add_theme_color_override("font_color", Color("ffe14a"))
	debug_label.add_theme_font_size_override("font_size", 10)
	debug_label.visible = false
	col.add_child(debug_label)

	music_button = Button.new()
	music_button.pressed.connect(func(): Sfx.toggle_music())
	music_button.focus_mode = Control.FOCUS_NONE
	col.add_child(music_button)


func _make_slot(title: String, parent: Control) -> VBoxContainer:
	var slot := VBoxContainer.new()
	slot.add_theme_constant_override("separation", 2)
	parent.add_child(slot)
	var l := Label.new()
	l.text = title
	l.add_theme_color_override("font_color", UiTheme.COL_DIM)
	l.add_theme_font_size_override("font_size", 10)
	slot.add_child(l)
	return slot


func _build_toast() -> void:
	toast_label = Label.new()
	toast_label.position = Vector2(0, 30)
	toast_label.size = Vector2(ARENA_W, 30)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 22)
	toast_label.add_theme_font_override("font", UiTheme.font(true))
	toast_label.add_theme_color_override("font_outline_color", Color.BLACK)
	toast_label.add_theme_constant_override("outline_size", 6)
	toast_label.modulate.a = 0.0
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(toast_label)


func _build_end_window() -> void:
	end_root = Control.new()
	end_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_root.visible = false
	_root.add_child(end_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_root.add_child(center)

	var win := PanelContainer.new()
	win.custom_minimum_size = Vector2(300, 0)
	center.add_child(win)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	win.add_child(v)

	end_title = Label.new()
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_title.add_theme_font_size_override("font_size", 30)
	end_title.add_theme_font_override("font", UiTheme.font(true))
	v.add_child(end_title)

	end_reason = Label.new()
	end_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_reason.add_theme_color_override("font_color", UiTheme.COL_DIM)
	v.add_child(end_reason)

	var sep := HSeparator.new()
	v.add_child(sep)

	end_again = Button.new()
	end_again.text = "Play again (R)"
	end_again.pressed.connect(func(): play_again_pressed.emit())
	v.add_child(end_again)

	var back := Button.new()
	back.text = "Back to lobby"
	back.pressed.connect(func(): back_to_lobby_pressed.emit())
	v.add_child(back)


# ---------------------------------------------------------------- public API

# Who am I? Puts MY panel under "YOUR STATS" and the other one under "ENEMY STATS".
func set_roles(me_is_human: bool) -> void:
	_me_is_human = me_is_human
	var mine: StatPanel = human_panel if me_is_human else mosquito_panel
	var theirs: StatPanel = mosquito_panel if me_is_human else human_panel
	for p in [mine, theirs]:
		if p.get_parent() != null:
			p.get_parent().remove_child(p)
	your_slot.add_child(mine)
	enemy_slot.add_child(theirs)
	if me_is_human:
		controls_label.text = "WASD move - mouse aims\nClick: SLAP (zap!)"
	else:
		controls_label.text = "WASD move - mouse aims\nClick: BITE (red dot = human)"


func set_time(left: float, total: float) -> void:
	timer_label.text = "%d" % ceili(left)
	timer_bar.value = clampf(left / maxf(total, 0.001), 0.0, 1.0)
	var urgent := left <= 10.0 and left > 0.0
	timer_label.add_theme_color_override("font_color", UiTheme.COL_DANGER if urgent else UiTheme.COL_TEXT)


func set_human_stats(hp: int, max_hp: int, slap_fraction: float, stun_left: float) -> void:
	var tex: Texture2D = HEART_0
	match hp:
		4: tex = HEART_FULL
		3: tex = HEART_75
		2: tex = HEART_50
		1: tex = HEART_25
		_: tex = HEART_0
	human_panel.set_heart(tex, "HP  %d / %d" % [hp, max_hp])
	var ready := slap_fraction >= 1.0
	human_panel.set_bar(slap_fraction, "SLAP  READY" if ready else "SLAP  recharging", ready)
	if stun_left > 0.0:
		human_panel.set_status("STUNNED %.1fs" % stun_left, UiTheme.COL_DANGER)
	else:
		human_panel.set_status("ok", UiTheme.COL_DIM)


func set_mosquito_stats(alive: bool, bite_fraction: float, boost_left: float) -> void:
	mosquito_panel.set_heart(HEART_FULL if alive else HEART_0, "LIFE  %d / 1" % (1 if alive else 0))
	var ready := bite_fraction >= 1.0
	mosquito_panel.set_bar(bite_fraction, "BITE  READY" if ready else "BITE  recharging", ready)
	if not alive:
		mosquito_panel.set_status("SQUASHED", UiTheme.COL_DANGER)
	elif boost_left > 0.0:
		mosquito_panel.set_status("SPEED BOOST!", UiTheme.COL_GOOD)
	else:
		mosquito_panel.set_status("ok", UiTheme.COL_DIM)


func toast(text: String, color: Color = Color.WHITE) -> void:
	toast_label.text = text
	toast_label.add_theme_color_override("font_color", color)
	if _toast_tween != null:
		_toast_tween.kill()
	toast_label.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(0.8)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)


func flash(color: Color) -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	flash_rect.color = Color(color.r, color.g, color.b, 0.35)
	_flash_tween = create_tween()
	_flash_tween.tween_property(flash_rect, "color:a", 0.0, 0.35)


func set_debug_text(text: String) -> void:
	debug_label.text = text.replace("\n", "  ")
	debug_label.visible = text != ""


func show_end(title: String, reason: String, won: bool, can_replay: bool) -> void:
	end_title.text = title
	end_title.add_theme_color_override("font_color", UiTheme.COL_GOOD if won else UiTheme.COL_DANGER)
	end_reason.text = reason
	end_again.visible = can_replay
	end_root.visible = true


func _on_music_changed(enabled: bool) -> void:
	if music_button != null:
		music_button.text = "Music: ON  (M)" if enabled else "Music: OFF (M)"
