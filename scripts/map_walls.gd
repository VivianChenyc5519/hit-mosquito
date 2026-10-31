extends Node2D
# Draws the "outside" of the map (every EMPTY cell of the TileMapLayer) as solid dark walls,
# so the players clearly see where the map ends. The collision for those cells is built in game.gd.

var wall_cells: Array[Vector2i] = []
var floor_lookup: Dictionary = {}
var tile: int = 16
var fill_color: Color = Color("503868")
var edge_color: Color = Color("c05aa8")


func _draw() -> void:
	for c in wall_cells:
		var r := Rect2(Vector2(c) * tile, Vector2(tile, tile))
		draw_rect(r, fill_color)
		# subtle brick pattern
		draw_rect(Rect2(r.position, Vector2(tile, 1)), fill_color.darkened(0.25))
		draw_rect(Rect2(r.position + Vector2((c.y % 2) * 8.0 + 7.0, 0), Vector2(1, tile)), fill_color.darkened(0.25))
		# bright edge on the sides that touch the floor
		if floor_lookup.has(c + Vector2i(0, 1)):
			draw_rect(Rect2(r.position + Vector2(0, tile - 2), Vector2(tile, 2)), edge_color)
		if floor_lookup.has(c + Vector2i(0, -1)):
			draw_rect(Rect2(r.position, Vector2(tile, 2)), edge_color)
		if floor_lookup.has(c + Vector2i(1, 0)):
			draw_rect(Rect2(r.position + Vector2(tile - 2, 0), Vector2(2, tile)), edge_color)
		if floor_lookup.has(c + Vector2i(-1, 0)):
			draw_rect(Rect2(r.position, Vector2(2, tile)), edge_color)
