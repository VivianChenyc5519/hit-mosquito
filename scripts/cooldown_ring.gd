extends Node2D
# Small circular cooldown indicator drawn by code (no texture needed).
# Call start(duration). The ring fills up and disappears when the cooldown is over.

var radius: float = 9.0
var thickness: float = 3.0
var ring_color: Color = Color(1, 0.85, 0.2)

var _total: float = 0.0
var _remaining: float = 0.0


func _ready() -> void:
	visible = false
	z_index = 50


func start(duration: float) -> void:
	_total = maxf(duration, 0.001)
	_remaining = duration
	visible = true
	queue_redraw()


func _process(delta: float) -> void:
	if _remaining <= 0.0:
		return
	_remaining = maxf(_remaining - delta, 0.0)
	if _remaining <= 0.0:
		visible = false
	queue_redraw()


func _draw() -> void:
	var progress := 1.0 - (_remaining / _total)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0, 0, 0, 0.5), thickness)
	if progress > 0.0:
		draw_arc(Vector2.ZERO, radius, -PI / 2.0, -PI / 2.0 + TAU * progress, 32, ring_color, thickness)
