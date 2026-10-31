class_name UiTheme
extends RefCounted
# One place that defines how every menu / HUD looks (pixel font + "mini window" panels).
# Usage: some_control.theme = UiTheme.make()

const FONT_REGULAR := "res://assets/font/static/PixelifySans-Regular.ttf"
const FONT_BOLD := "res://assets/font/static/PixelifySans-Bold.ttf"

const COL_TEXT := Color("efe8f4")   # soft white (racket mesh)
const COL_DIM := Color("a495bd")
const COL_PANEL := Color("221832")   # deep plum (racket shadow)
const COL_PANEL_DARK := Color("140e20")
const COL_BORDER := Color("783880")  # racket purple
const COL_ACCENT := Color("f8f0c0")   # electric spark yellow
const COL_HUMAN := Color("f878d8")    # racket hot pink
const COL_MOSQUITO := Color("70b0d8") # spark blue
const COL_GOOD := Color("b0e0d8")      # mint (spark highlight)
const COL_DANGER := Color("ff6a8a")


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
	t.set_stylebox("normal", "Button", box(Color("3a2650"), COL_BORDER, 2, 10, 5))
	t.set_stylebox("hover", "Button", box(Color("5a2e70"), COL_ACCENT, 2, 10, 5))
	t.set_stylebox("pressed", "Button", box(Color("2a1a3c"), COL_ACCENT, 2, 10, 7))
	t.set_stylebox("disabled", "Button", box(Color("1a1326"), Color("33264a"), 2, 10, 5))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", COL_TEXT)
	t.set_color("font_hover_color", "Button", COL_ACCENT)
	t.set_color("font_pressed_color", "Button", COL_ACCENT)
	t.set_color("font_disabled_color", "Button", Color("6a5c82"))
	t.set_font_size("font_size", "Button", 12)

	# --- Text input ---
	t.set_stylebox("normal", "LineEdit", box(COL_PANEL_DARK, COL_BORDER, 2, 8, 5))
	t.set_stylebox("focus", "LineEdit", box(COL_PANEL_DARK, COL_ACCENT, 2, 8, 5))
	t.set_stylebox("read_only", "LineEdit", box(Color("140e20"), Color("33264a"), 2, 8, 5))
	t.set_color("font_color", "LineEdit", COL_TEXT)
	t.set_color("font_uneditable_color", "LineEdit", COL_DIM)
	t.set_color("font_placeholder_color", "LineEdit", Color("6a5c82"))
	t.set_color("caret_color", "LineEdit", COL_ACCENT)

	# --- Progress bars (cooldowns) ---
	var bar_bg := box(COL_PANEL_DARK, Color("33264a"), 1, 0, 0)
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
