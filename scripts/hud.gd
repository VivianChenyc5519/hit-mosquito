extends CanvasLayer
class_name HUD

@onready var heart_texture: TextureRect = $Root/HeartTexture

@export var heart_dead: Texture2D
@export var heart_25: Texture2D
@export var heart_50: Texture2D
@export var heart_75: Texture2D
@export var heart_full: Texture2D

func set_human_hp(current_hp: int, _max_hp: int) -> void:
	match current_hp:
		4: 
			heart_texture.texture = heart_full
		3:
			heart_texture.texture = heart_75
		2:
			heart_texture.texture = heart_50
		1: 
			heart_texture.texture = heart_25
		0:
			heart_texture.texture = heart_dead

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
