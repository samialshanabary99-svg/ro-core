extends CharacterBody2D

@onready var renderer: CharacterBody2D = $EntityRenderer

var grid_pos: Vector2i = Vector2i.ZERO
var is_moving: bool = false
var current_dir: int = 0

func _ready() -> void:
	renderer.is_remote = false
	GameState.local_player_node = self

func _input(event: InputEvent) -> void:
	if GameState.input_mode != "game":
		return
		
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var global_mouse: Vector2 = get_global_mouse_position()
		var target_tile: Vector2i = Vector2i(floor(global_mouse.x / 32.0), floor(global_mouse.y / 32.0))
		
		var target_entity_id: String = _detect_entity_at_pixel(global_mouse)
		if not target_entity_id.is_empty():
			renderer.play_action("attack")
			NetworkManager.send_attack_request(target_entity_id)
		else:
			_issue_walk_request(target_tile)

func _issue_walk_request(target_tile: Vector2i) -> void:
	var current_tile: Vector2i = Vector2i(floor(position.x / 32.0), floor(position.y / 32.0))
	var map_loader = get_node_or_null("/root/Main/GameWorld/MapRenderer")
	
	if map_loader and not map_loader.is_walkable(target_tile.x, target_tile.y):
		return
		
	var delta: Vector2i = target_tile - current_tile
	if delta.x < 0: current_dir = 1
	elif delta.x > 0: current_dir = 2
	elif delta.y < 0: current_dir = 3
	elif delta.y > 0: current_dir = 0
	
	NetworkManager.send_walk_request(target_tile.x, target_tile.y, current_dir)
	_predict_local_movement(target_tile)

func _predict_local_movement(target_tile: Vector2i) -> void:
	var current_tile: Vector2i = Vector2i(floor(position.x / 32.0), floor(position.y / 32.0))
	var distance_tiles: int = current_tile.distance_to(target_tile)
	var duration: float = max(distance_tiles * 0.2, 0.15)  # 200ms per tile, min 150ms
	
	var target_pixels: Vector2 = Vector2(target_tile.x * 32, target_tile.y * 32)
	var tween = create_tween()
	renderer.play_action("walk")
	tween.tween_property(self, "position", target_pixels, duration)
	await tween.finished
	renderer.play_action("idle")

func _detect_entity_at_pixel(mouse_pos: Vector2) -> String:
	var remotes_node = get_node_or_null("/root/Main/GameWorld/EntityLayer/RemoteEntities")
	if not remotes_node:
		return ""
	for entity in remotes_node.get_children():
		if entity.position.distance_to(mouse_pos) < 24.0:
			return entity.entity_id
	return ""