extends EntitySprite
class_name PlayerController
## Player-controlled entity with input handling, client-side prediction,
## and server reconciliation for smooth networked movement

# Input state
var input_direction: Vector2 = Vector2.ZERO
var last_input_time: float = 0.0
var input_buffer: Array[Dictionary] = []

# Client-side prediction
var predicted_position: Vector2 = Vector2.ZERO
var server_position: Vector2 = Vector2.ZERO
var reconcile_threshold: float = 32.0  # Pixels before hard correction
var smooth_correction_speed: float = 10.0

# Movement settings
var tile_size: int = 32
var move_delay: float = 0.15  # Seconds between movement inputs
var can_move: bool = true

# Attack settings
var attack_delay: float = 0.8  # ASPD-based
var can_attack: bool = true
var attack_target_id: int = -1

# References
var map_loader: Node = null
var camera: Camera2D = null

# Signals
signal player_moved(from: Vector2, to: Vector2, direction: int)
signal player_attacked(target_id: int)
signal player_pickup_requested
signal player_interact_requested(target_id: int)


func _ready() -> void:
	super._ready()
	entity_type = "player"
	
	# Connect to game state signals
	if GameState:
		GameState.position_updated.connect(_on_server_position_update)
		GameState.stats_changed.connect(_on_stats_changed)
	
	# Connect to packet handler for server responses
	if PacketHandler:
		PacketHandler.move_ack_received.connect(_on_move_ack)
		PacketHandler.attack_result_received.connect(_on_attack_result)


func _process(delta: float) -> void:
	super._process(delta)
	
	if not can_move:
		return
	
	_handle_input()
	_apply_prediction_correction(delta)


func _unhandled_input(event: InputEvent) -> void:
	# Attack input (Space or click on enemy)
	if event.is_action_pressed("attack") and can_attack:
		_try_attack()
	
	# Pickup items (Z key)
	if event.is_action_pressed("pickup"):
		player_pickup_requested.emit()
		_send_pickup_request()
	
	# Open stats (F1)
	if event.is_action_pressed("stats"):
		# UI will handle this via signal
		pass


## Handle movement input
func _handle_input() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	
	if now - last_input_time < move_delay:
		return
	
	# Get input direction
	input_direction = Vector2.ZERO
	
	if Input.is_action_pressed("move_up"):
		input_direction.y -= 1
	if Input.is_action_pressed("move_down"):
		input_direction.y += 1
	if Input.is_action_pressed("move_left"):
		input_direction.x -= 1
	if Input.is_action_pressed("move_right"):
		input_direction.x += 1
	
	if input_direction == Vector2.ZERO:
		return
	
	input_direction = input_direction.normalized()
	
	# Calculate target tile
	var current_tile := _world_to_tile(position)
	var target_tile := current_tile + Vector2i(
		roundi(input_direction.x),
		roundi(input_direction.y)
	)
	
	# Check walkability
	if map_loader and not map_loader.is_walkable(target_tile.x, target_tile.y):
		return
	
	# Apply client-side prediction
	var target_world := _tile_to_world(target_tile)
	_apply_prediction(target_world)
	
	# Send to server
	_send_move_request(target_tile)
	
	last_input_time = now


## Apply client-side movement prediction
func _apply_prediction(target: Vector2) -> void:
	var from_pos := position
	predicted_position = target
	
	# Store in input buffer for reconciliation
	input_buffer.append({
		"time": Time.get_ticks_msec(),
		"from": from_pos,
		"to": target,
		"direction": direction
	})
	
	# Cap buffer size
	if input_buffer.size() > 60:
		input_buffer.pop_front()
	
	# Start moving visually
	var dir := direction_from_vector(target - position)
	set_direction(dir)
	move_to(target)
	
	player_moved.emit(from_pos, target, dir)


## Send movement request to server
func _send_move_request(tile: Vector2i) -> void:
	if NetworkManager and NetworkManager.is_socket_connected():
		NetworkManager.send_walk(tile.x, tile.y)


## Handle server position acknowledgment
func _on_move_ack(x: int, y: int, tick: int) -> void:
	server_position = _tile_to_world(Vector2i(x, y))
	
	# Check if we need to reconcile
	var diff := predicted_position.distance_to(server_position)
	
	if diff > reconcile_threshold:
		# Hard correction - teleport
		teleport_to(server_position)
		predicted_position = server_position
		input_buffer.clear()
	elif diff > 1.0:
		# Soft correction - will be smoothed in _apply_prediction_correction
		pass


## Smoothly correct position towards server state
func _apply_prediction_correction(delta: float) -> void:
	if server_position == Vector2.ZERO:
		return
	
	var diff := position.distance_to(server_position)
	
	if diff > 1.0 and diff < reconcile_threshold:
		# Smooth interpolation towards server position
		position = position.lerp(server_position, smooth_correction_speed * delta)


## Handle server position update (from GameState)
func _on_server_position_update(pos: Vector2) -> void:
	server_position = pos


## Try to attack current target or nearest enemy
func _try_attack() -> void:
	if not can_attack:
		return
	
	can_attack = false
	
	# Find attack target
	var target_id := attack_target_id
	if target_id < 0:
		target_id = _find_nearest_enemy()
	
	if target_id < 0:
		can_attack = true
		return
	
	# Visual attack animation
	play_attack()
	
	# Send attack request
	if NetworkManager and NetworkManager.is_socket_connected():
		NetworkManager.send_attack(target_id, 0)  # 0 = normal attack
	
	player_attacked.emit(target_id)
	
	# Reset attack cooldown
	await get_tree().create_timer(attack_delay).timeout
	can_attack = true


## Find nearest enemy entity
func _find_nearest_enemy() -> int:
	if not GameState:
		return -1
	
	var nearest_id := -1
	var nearest_dist := 999999.0
	var attack_range := tile_size * 1.5  # Melee range
	
	for id in GameState.entities:
		var ent: Dictionary = GameState.entities[id]
		if ent.get("type") == "monster":
			var ent_pos := Vector2(ent.get("x", 0) * tile_size, ent.get("y", 0) * tile_size)
			var dist := position.distance_to(ent_pos)
			if dist < attack_range and dist < nearest_dist:
				nearest_dist = dist
				nearest_id = id
	
	return nearest_id


## Handle attack result from server
func _on_attack_result(target_id: int, damage: int, target_hp: int) -> void:
	# This would trigger damage display on target entity
	# The EntityManager will handle finding and updating the target
	pass


## Send pickup request to server
func _send_pickup_request() -> void:
	if NetworkManager and NetworkManager.is_socket_connected():
		NetworkManager.send_pickup()


## Handle stats change (update attack speed)
func _on_stats_changed() -> void:
	if GameState and GameState.stats.has("aspd"):
		# ASPD formula: delay = 200 / (100 + aspd)
		var aspd: int = GameState.stats.get("aspd", 100)
		attack_delay = 2.0 / (1.0 + aspd / 100.0)


## Set the map loader reference
func set_map_loader(loader: Node) -> void:
	map_loader = loader


## Set the camera reference
func set_camera(cam: Camera2D) -> void:
	camera = cam


## Convert world position to tile coordinates
func _world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / tile_size),
		floori(world_pos.y / tile_size)
	)


## Convert tile coordinates to world position (center of tile)
func _tile_to_world(tile: Vector2i) -> Vector2:
	return Vector2(
		tile.x * tile_size + tile_size / 2.0,
		tile.y * tile_size + tile_size / 2.0
	)


## Initialize player with character data
func setup_player(char_data: Dictionary) -> void:
	entity_id = char_data.get("char_id", 0)
	entity_name = char_data.get("name", "Player")
	job_id = char_data.get("job", 0)
	
	var x: int = char_data.get("x", 0)
	var y: int = char_data.get("y", 0)
	var pos := _tile_to_world(Vector2i(x, y))
	
	setup(entity_id, "player", entity_name, pos, job_id)
	
	predicted_position = pos
	server_position = pos


## Handle mouse click for movement or targeting
func handle_click(world_pos: Vector2, button: int) -> void:
	if button == MOUSE_BUTTON_LEFT:
		# Check if clicking on an entity
		var clicked_entity := _get_entity_at_position(world_pos)
		
		if clicked_entity > 0:
			# Target this entity
			attack_target_id = clicked_entity
			player_interact_requested.emit(clicked_entity)
		else:
			# Move to clicked position
			var target_tile := _world_to_tile(world_pos)
			if map_loader and map_loader.is_walkable(target_tile.x, target_tile.y):
				var target_world := _tile_to_world(target_tile)
				_apply_prediction(target_world)
				_send_move_request(target_tile)
	
	elif button == MOUSE_BUTTON_RIGHT:
		# Clear target
		attack_target_id = -1


## Get entity at world position
func _get_entity_at_position(world_pos: Vector2) -> int:
	if not GameState:
		return -1
	
	var click_radius := 16.0
	
	for id in GameState.entities:
		var ent: Dictionary = GameState.entities[id]
		var ent_pos := Vector2(
			ent.get("x", 0) * tile_size + tile_size / 2.0,
			ent.get("y", 0) * tile_size + tile_size / 2.0
		)
		
		if world_pos.distance_to(ent_pos) < click_radius:
			return id
	
	return -1


## Enable/disable player control
func set_control_enabled(enabled: bool) -> void:
	can_move = enabled
	can_attack = enabled
	set_process_unhandled_input(enabled)
