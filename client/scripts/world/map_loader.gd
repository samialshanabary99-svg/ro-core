extends Node2D

@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var fringe_layer: TileMapLayer = $FringeLayer
@onready var collision_layer: TileMapLayer = $CollisionLayer

var map_width: int = 0
var map_height: int = 0
var _collision_matrix: Array = []

func _ready() -> void:
	collision_layer.visible = false

func load_map(map_data: Dictionary) -> void:
	ground_layer.clear()
	fringe_layer.clear()
	collision_layer.clear()
	
	map_width = map_data.get("width", 60)
	map_height = map_data.get("height", 60)
	var raw_grid = map_data.get("collision", [])
	_collision_matrix = raw_grid
	
	for x in range(map_width):
		for y in range(map_height):
			ground_layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
			
			var is_blocked: bool = false
			if y < raw_grid.size() and x < raw_grid[y].size():
				is_blocked = (raw_grid[y][x] == 1)
				
			if is_blocked:
				collision_layer.set_cell(Vector2i(x, y), 0, Vector2i(1, 0))

func is_walkable(x: int, y: int) -> bool:
	if x < 0 or x >= map_width or y < 0 or y >= map_height:
		return false
	if _collision_matrix.size() > y and _collision_matrix[y].size() > x:
		return _collision_matrix[y][x] != 1
	return true