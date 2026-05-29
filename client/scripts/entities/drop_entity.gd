extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
var drop_uid: String

func setup(drop_data: Dictionary) -> void:
	drop_uid = drop_data.get("uid", "drop_" + str(randi()))
	var item_id = drop_data.get("item_id", 909)
	
	sprite.texture = SpriteLoader.load_drop_icon(item_id)
	position = Vector2(drop_data.get("x", 0) * 32, drop_data.get("y", 0) * 32)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if get_global_mouse_position().distance_to(position) < 16.0:
			NetworkManager.send_pickup_request(drop_uid)
			queue_free()