class_name UiTheme
extends RefCounted
# One place that defines how every menu / HUD looks (pixel font + "mini window" panels).
# Usage: some_control.theme = UiTheme.make()

const FONT_REGULAR := "res://assets/font/static/PixelifySans-Regular.ttf"
const FONT_BOLD := "res://assets/font/static/PixelifySans-Bold.ttf"

const COL_TEXT := Color("e9e9f2")
const COL_DIM := Color("8d90b3")
const COL_PANEL := Color("171828")
const COL_PANEL_DARK := Color("0f1019")
const COL_BORDER := Color("464a78")
const COL_ACCENT := Color("ffcf4a")   # flashlight yellow
const COL_HUMAN := Color("ffcf4a")
const COL_MOSQUITO := Color("ff5d5d")
const COL_GOOD := Color("5dff9a")


static func font(bold: bool = false) -> Font:
	var path: String = FONT_BOLD if bold else FONT_REGULAR
	if ResourceLoader.exists(path):
		return load(path) as Font
	return ThemeDB.fallback_font


static func box(bg: Color, border: Color, border_w: int = 2, margin_h: float = 8.0, margin_v: float = 6.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(0)  # square corners = pixel look
	sb.content_margin_left = margin_h
	sb.content_margin_right = margin_h
	sb.content_margin_top = margin_v
	sb.content_margin_bottom = margin_v
	return sb


static func make() -> Theme:
	var t := Theme.new()
	t.default_font = font(false)
	t.default_font_size = 12

	# --- Labels ---
	t.set_color("font_color", "Label", COL_TEXT)
	t.set_font("font", "Label", font(false))

	# --- Panels ("mini windows") ---
	t.set_stylebox("panel", "PanelContainer", box(COL_PANEL, COL_BORDER, 2, 8, 6))
	t.set_stylebox("panel", "Panel", box(COL_PANEL, COL_BORDER, 2))

	# --- Buttons ---
	t.set_stylebox("normal", "Button", box(Color("2a2c4a"), COL_BORDER, 2, 10, 5))
	t.set_stylebox("hover", "Button", box(Color("3a3e69"), COL_ACCENT, 2, 10, 5))
	t.set_stylebox("pressed", "Button", box(Color("1d1e36"), COL_ACCENT, 2, 10, 7))
	t.set_stylebox("disabled", "Button", box(Color("181924"), Color("2c2d3f"), 2, 10, 5))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", COL_TEXT)
	t.set_color("font_hover_color", "Button", COL_ACCENT)
	t.set_color("font_pressed_color", "Button", COL_ACCENT)
	t.set_color("font_disabled_color", "Button", Color("5c5e78"))
	t.set_font_size("font_size", "Button", 12)

	# --- Text input ---
	t.set_stylebox("normal", "LineEdit", box(COL_PANEL_DARK, COL_BORDER, 2, 8, 5))
	t.set_stylebox("focus", "LineEdit", box(COL_PANEL_DARK, COL_ACCENT, 2, 8, 5))
	t.set_stylebox("read_only", "LineEdit", box(Color("14151f"), Color("2c2d3f"), 2, 8, 5))
	t.set_color("font_color", "LineEdit", COL_TEXT)
	t.set_color("font_uneditable_color", "LineEdit", COL_DIM)
	t.set_color("font_placeholder_color", "LineEdit", Color("5c5e78"))
	t.set_color("caret_color", "LineEdit", COL_ACCENT)

	# --- Progress bars (cooldowns) ---
	var bar_bg := box(COL_PANEL_DARK, Color("2c2d3f"), 1, 0, 0)
	var bar_fill := box(COL_ACCENT, COL_ACCENT, 0, 0, 0)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)

	# --- Separator ---
	var line := StyleBoxLine.new()
	line.color = COL_BORDER
	line.thickness = 2
	t.set_stylebox("separator", "HSeparator", line)
	t.set_constant("separation", "HSeparator", 8)
	return t


# Handy: a StyleBoxFlat clone with another fill color (for coloured progress bars).
static func fill_box(color: Color) -> StyleBoxFlat:
	return box(color, color, 0, 0, 0)
