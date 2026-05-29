extends Node
class_name MapLoader
## MapLoader - Parses map data and builds TileMap layers
## Handles collision grid, spawn points, and warp zones

signal map_loaded(map_name: String)
signal map_load_failed(error: String)

const TILE_SIZE: int = 32

## Map data cache
var _current_map: Dictionary = {}
var _collision_grid: Array = []  # 2D array: 0=walkable, 1=blocked
var _spawn_points: Array = []
var _warp_zones: Array = []

## Node references
var _ground_layer: TileMapLayer
var _fringe_layer: TileMapLayer
var _collision_layer: TileMapLayer

## Map dimensions
var map_width: int = 0
var map_height: int = 0
var map_name: String = ""


func _ready() -> void:
	_setup_tilemap_layers()


## Setup the TileMap layers for rendering
func _setup_tilemap_layers() -> void:
	# Ground layer - base terrain
	_ground_layer = TileMapLayer.new()
	_ground_layer.name = "GroundLayer"
	_ground_layer.z_index = -10
	add_child(_ground_layer)
	
	# Fringe layer - walkable decorations
	_fringe_layer = TileMapLayer.new()
	_fringe_layer.name = "FringeLayer"
	_fringe_layer.z_index = -5
	add_child(_fringe_layer)
	
	# Collision layer - visual debug (hidden in production)
	_collision_layer = TileMapLayer.new()
	_collision_layer.name = "CollisionLayer"
	_collision_layer.z_index = 100
	_collision_layer.visible = false  # Enable for debugging
	add_child(_collision_layer)


## Load a map by name from server data or local cache
func load_map(name: String, map_data: Dictionary = {}) -> bool:
	map_name = name
	
	if map_data.is_empty():
		# Try to load from local YAML cache (for offline testing)
		map_data = _load_local_map_data(name)
	
	if map_data.is_empty():
		map_load_failed.emit("Map data not found: %s" % name)
		return false
	
	_current_map = map_data
	map_width = map_data.get("width", 60)
	map_height = map_data.get("height", 60)
	
	# Parse collision grid
	_parse_collision_grid(map_data.get("collision", []))
	
	# Parse spawn points
	_spawn_points = map_data.get("spawns", [])
	
	# Parse warp zones
	_warp_zones = map_data.get("warps", [])
	
	# Build the visual tilemap
	_build_tilemap()
	
	map_loaded.emit(map_name)
	return true


## Load map data from local YAML file (fallback)
func _load_local_map_data(name: String) -> Dictionary:
	var path := "res://data/maps/%s.yml" % name
	
	if not FileAccess.file_exists(path):
		# Return default prt_fild01 data for testing
		if name == "prt_fild01":
			return _get_default_prt_fild01()
		return {}
	
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	
	var content := file.get_as_text()
	file.close()
	
	# Simple YAML parsing (basic key-value)
	return _parse_simple_yaml(content)


## Get default prt_fild01 data for testing
func _get_default_prt_fild01() -> Dictionary:
	return {
		"id": "prt_fild01",
		"name": "Prontera Field 01",
		"width": 60,
		"height": 60,
		"tile_size": 32,
		"collision": _generate_default_collision(60, 60),
		"spawns": [
			{"mob_id": 1002, "x": 15, "y": 20, "radius": 5, "amount": 1, "delay": 5000},
			{"mob_id": 1002, "x": 40, "y": 35, "radius": 5, "amount": 1, "delay": 5000},
			{"mob_id": 1002, "x": 25, "y": 50, "radius": 5, "amount": 1, "delay": 5000}
		],
		"warps": [
			{"x": 0, "y": 30, "target_map": "prontera", "target_x": 150, "target_y": 100}
		]
	}


## Generate default collision grid with border walls
func _generate_default_collision(width: int, height: int) -> Array:
	var grid: Array = []
	for y in range(height):
		var row: Array = []
		for x in range(width):
			# Border walls
			if x == 0 or x == width - 1 or y == 0 or y == height - 1:
				row.append(1)
			# Some random obstacles for variety
			elif (x == 20 and y >= 15 and y <= 25) or (x >= 35 and x <= 45 and y == 30):
				row.append(1)
			else:
				row.append(0)
		grid.append(row)
	return grid


## Parse collision grid from map data
func _parse_collision_grid(data: Variant) -> void:
	_collision_grid.clear()
	
	if data is Array and data.size() > 0:
		_collision_grid = data
	else:
		# Generate default grid if none provided
		_collision_grid = _generate_default_collision(map_width, map_height)


## Build the visual TileMap from collision data
func _build_tilemap() -> void:
	# Clear existing tiles
	_ground_layer.clear()
	_fringe_layer.clear()
	_collision_layer.clear()
	
	# Create a simple TileSet programmatically
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	
	# Create tile source (using colored squares as placeholders)
	var source := TileSetAtlasSource.new()
	source.texture = _create_placeholder_texture()
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	
	# Add tiles: 0=grass, 1=blocked, 2=warp
	source.create_tile(Vector2i(0, 0))  # Grass
	source.create_tile(Vector2i(1, 0))  # Blocked
	source.create_tile(Vector2i(2, 0))  # Warp zone
	
	tileset.add_source(source, 0)
	
	_ground_layer.tile_set = tileset
	_collision_layer.tile_set = tileset
	
	# Place tiles based on collision grid
	for y in range(map_height):
		for x in range(map_width):
			var is_blocked := _is_tile_blocked(x, y)
			var is_warp := _is_warp_tile(x, y)
			
			# Ground layer - all tiles get grass
			_ground_layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
			
			# Collision layer - show blocked tiles (debug)
			if is_blocked:
				_collision_layer.set_cell(Vector2i(x, y), 0, Vector2i(1, 0))
			elif is_warp:
				_collision_layer.set_cell(Vector2i(x, y), 0, Vector2i(2, 0))


## Create placeholder texture atlas for tiles
func _create_placeholder_texture() -> ImageTexture:
	var img := Image.create(TILE_SIZE * 3, TILE_SIZE, false, Image.FORMAT_RGBA8)
	
	# Grass tile (green)
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var shade := 0.7 + randf() * 0.15
			img.set_pixel(x, y, Color(0.2 * shade, 0.6 * shade, 0.2 * shade))
	
	# Blocked tile (dark gray/brown)
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE + 0, TILE_SIZE * 2):
			var shade := 0.3 + randf() * 0.1
			img.set_pixel(x, y, Color(shade, shade * 0.8, shade * 0.6))
	
	# Warp tile (blue glow)
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE * 2, TILE_SIZE * 3):
			var dist := Vector2(x - TILE_SIZE * 2.5, y - TILE_SIZE / 2.0).length()
			var glow := clampf(1.0 - dist / (TILE_SIZE * 0.5), 0.3, 1.0)
			img.set_pixel(x, y, Color(0.2 * glow, 0.4 * glow, 0.9 * glow, 0.8))
	
	return ImageTexture.create_from_image(img)


## Simple YAML parser (handles basic maps.yml structure)
func _parse_simple_yaml(content: String) -> Dictionary:
	var result: Dictionary = {}
	var lines := content.split("\n")
	var current_key := ""
	
	for line in lines:
		line = line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		
		if ":" in line:
			var parts := line.split(":", true, 1)
			var key := parts[0].strip_edges()
			var value := parts[1].strip_edges() if parts.size() > 1 else ""
			
			if value.is_empty():
				current_key = key
			else:
				result[key] = _parse_yaml_value(value)
	
	return result


## Parse YAML value to appropriate type
func _parse_yaml_value(value: String) -> Variant:
	value = value.strip_edges()
	
	# Remove quotes
	if value.begins_with("\"") and value.ends_with("\""):
		return value.substr(1, value.length() - 2)
	if value.begins_with("'") and value.ends_with("'"):
		return value.substr(1, value.length() - 2)
	
	# Boolean
	if value == "true":
		return true
	if value == "false":
		return false
	
	# Number
	if value.is_valid_int():
		return value.to_int()
	if value.is_valid_float():
		return value.to_float()
	
	return value


## Check if a tile position is blocked
func is_walkable(x: int, y: int) -> bool:
	return not _is_tile_blocked(x, y)


func _is_tile_blocked(x: int, y: int) -> bool:
	if x < 0 or x >= map_width or y < 0 or y >= map_height:
		return true
	
	if _collision_grid.size() <= y:
		return false
	
	var row: Variant = _collision_grid[y]
	if row is Array and row.size() > x:
		return row[x] == 1
	
	return false


## Check if position is a warp tile
func _is_warp_tile(x: int, y: int) -> bool:
	for warp in _warp_zones:
		if warp.get("x", -1) == x and warp.get("y", -1) == y:
			return true
	return false


## Get warp destination if standing on a warp tile
func get_warp_at(x: int, y: int) -> Dictionary:
	for warp in _warp_zones:
		if warp.get("x", -1) == x and warp.get("y", -1) == y:
			return warp
	return {}


## Convert tile coordinates to world position
func tile_to_world(tile_x: int, tile_y: int) -> Vector2:
	return Vector2(tile_x * TILE_SIZE + TILE_SIZE / 2.0, tile_y * TILE_SIZE + TILE_SIZE / 2.0)


## Convert world position to tile coordinates
func world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(world_pos.x / TILE_SIZE),
		int(world_pos.y / TILE_SIZE)
	)


## Get spawn points for a specific mob type
func get_spawns_for_mob(mob_id: int) -> Array:
	var result: Array = []
	for spawn in _spawn_points:
		if spawn.get("mob_id", 0) == mob_id:
			result.append(spawn)
	return result


## Get all spawn points
func get_all_spawns() -> Array:
	return _spawn_points.duplicate()


## Get map bounds in world coordinates
func get_world_bounds() -> Rect2:
	return Rect2(0, 0, map_width * TILE_SIZE, map_height * TILE_SIZE)


## Toggle collision layer visibility (debug)
func show_collision_debug(visible: bool) -> void:
	_collision_layer.visible = visible


## Find path between two tiles using A* (simple implementation)
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	
	if not is_walkable(to.x, to.y):
		return path
	
	# Simple A* pathfinding
	var open_set: Array = [from]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {from: 0}
	var f_score: Dictionary = {from: _heuristic(from, to)}
	
	while open_set.size() > 0:
		# Find node with lowest f_score
		var current: Vector2i = open_set[0]
		var lowest_f: float = f_score.get(current, INF)
		for node in open_set:
			var f: float = f_score.get(node, INF)
			if f < lowest_f:
				lowest_f = f
				current = node
		
		if current == to:
			# Reconstruct path
			path.append(current)
			while current in came_from:
				current = came_from[current]
				path.insert(0, current)
			return path
		
		open_set.erase(current)
		
		# Check neighbors (4-directional)
		var neighbors := [
			Vector2i(current.x + 1, current.y),
			Vector2i(current.x - 1, current.y),
			Vector2i(current.x, current.y + 1),
			Vector2i(current.x, current.y - 1)
		]
		
		for neighbor in neighbors:
			if not is_walkable(neighbor.x, neighbor.y):
				continue
			
			var tentative_g: float = g_score.get(current, INF) + 1.0
			
			if tentative_g < g_score.get(neighbor, INF):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + _heuristic(neighbor, to)
				
				if neighbor not in open_set:
					open_set.append(neighbor)
	
	return path  # Empty if no path found


func _heuristic(a: Vector2i, b: Vector2i) -> float:
	return abs(a.x - b.x) + abs(a.y - b.y)  # Manhattan distance
