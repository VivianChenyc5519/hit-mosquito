extends Node2D
# Mosquito-only: shows the human as a flickering red dot ("sensing" them).

var target: Node2D
var flicker_speed: float = 12.0
var _t: float = 0.0


func _ready() -> void:
	z_index = 100


func _process(delta: float) -> void:
	_t += delta
	if target:
		global_position = target.global_position
	queue_redraw()


func _draw() -> void:
	var a := 0.35 + 0.65 * (0.5 + 0.5 * sin(_t * flicker_speed))
	draw_circle(Vector2.ZERO, 9.0, Color(1, 0, 0, a * 0.35))
	draw_circle(Vector2.ZERO, 5.0, Color(1, 0.1, 0.1, a))
