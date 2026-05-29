extends Camera2D
class_name GameCamera
## GameCamera - Smooth following camera with bounds clamping
## Follows player with configurable smoothing and zoom

signal camera_moved(position: Vector2)

## Target to follow (usually player)
var _target: Node2D = null

## Camera settings
@export var follow_smoothing: float = 5.0  # Higher = faster follow
@export var zoom_level: float = 2.0  # 2x zoom for pixel art
@export var edge_margin: float = 100.0  # Pixels from edge before camera moves

## Map bounds (set by MapLoader)
var _map_bounds: Rect2 = Rect2()
var _half_viewport: Vector2 = Vector2.ZERO

## Shake effect
var _shake_intensity: float = 0.0
var _shake_decay: float = 5.0
var _shake_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Enable camera
	enabled = true
	make_current()
	
	# Set initial zoom
	zoom = Vector2(zoom_level, zoom_level)
	
	# Calculate viewport size
	_update_viewport_size()
	
	# Connect to viewport resize
	get_viewport().size_changed.connect(_on_viewport_resized)


func _process(delta: float) -> void:
	if _target == null:
		return
	
	# Calculate target position
	var target_pos: Vector2 = _target.global_position
	
	# Smooth follow
	var new_pos: Vector2 = global_position.lerp(target_pos, follow_smoothing * delta)
	
	# Clamp to map bounds if set
	if _map_bounds.size != Vector2.ZERO:
		new_pos = _clamp_to_bounds(new_pos)
	
	# Apply shake offset
	_update_shake(delta)
	new_pos += _shake_offset
	
	# Apply position
	global_position = new_pos
	
	# Emit signal for minimap or other systems
	camera_moved.emit(new_pos)


## Set the target node to follow
func set_target(target: Node2D) -> void:
	_target = target
	
	# Immediately snap to target on first set
	if _target != null:
		global_position = _target.global_position
		if _map_bounds.size != Vector2.ZERO:
			global_position = _clamp_to_bounds(global_position)


## Set map bounds for camera clamping
func set_map_bounds(bounds: Rect2) -> void:
	_map_bounds = bounds
	_update_viewport_size()


## Update viewport size calculation
func _update_viewport_size() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	_half_viewport = viewport_size / (2.0 * zoom_level)


## Clamp position to stay within map bounds
func _clamp_to_bounds(pos: Vector2) -> Vector2:
	var min_x: float = _map_bounds.position.x + _half_viewport.x
	var max_x: float = _map_bounds.end.x - _half_viewport.x
	var min_y: float = _map_bounds.position.y + _half_viewport.y
	var max_y: float = _map_bounds.end.y - _half_viewport.y
	
	# Handle case where map is smaller than viewport
	if min_x > max_x:
		pos.x = _map_bounds.get_center().x
	else:
		pos.x = clampf(pos.x, min_x, max_x)
	
	if min_y > max_y:
		pos.y = _map_bounds.get_center().y
	else:
		pos.y = clampf(pos.y, min_y, max_y)
	
	return pos


## Start camera shake effect
func shake(intensity: float = 5.0, decay: float = 5.0) -> void:
	_shake_intensity = intensity
	_shake_decay = decay


## Update shake effect
func _update_shake(delta: float) -> void:
	if _shake_intensity > 0.1:
		_shake_offset = Vector2(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		)
		_shake_intensity = lerpf(_shake_intensity, 0.0, _shake_decay * delta)
	else:
		_shake_intensity = 0.0
		_shake_offset = Vector2.ZERO


## Set zoom level (clamped between 0.5 and 4.0)
func set_zoom_level(level: float) -> void:
	zoom_level = clampf(level, 0.5, 4.0)
	zoom = Vector2(zoom_level, zoom_level)
	_update_viewport_size()


## Zoom in
func zoom_in(amount: float = 0.25) -> void:
	set_zoom_level(zoom_level + amount)


## Zoom out
func zoom_out(amount: float = 0.25) -> void:
	set_zoom_level(zoom_level - amount)


## Instantly move to position (no smoothing)
func snap_to(pos: Vector2) -> void:
	global_position = pos
	if _map_bounds.size != Vector2.ZERO:
		global_position = _clamp_to_bounds(global_position)


## Get visible rect in world coordinates
func get_visible_rect() -> Rect2:
	var size: Vector2 = get_viewport_rect().size / zoom
	return Rect2(global_position - size / 2.0, size)


## Check if a world position is visible on screen
func is_position_visible(world_pos: Vector2) -> bool:
	return get_visible_rect().has_point(world_pos)


## Convert screen position to world position
func screen_to_world(screen_pos: Vector2) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var offset: Vector2 = (screen_pos - viewport_size / 2.0) / zoom
	return global_position + offset


## Convert world position to screen position
func world_to_screen(world_pos: Vector2) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var offset: Vector2 = (world_pos - global_position) * zoom
	return viewport_size / 2.0 + offset


## Handle viewport resize
func _on_viewport_resized() -> void:
	_update_viewport_size()


## Handle zoom input (optional - can be connected to input events)
func handle_zoom_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.pressed:
			match mouse_event.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					zoom_in(0.1)
				MOUSE_BUTTON_WHEEL_DOWN:
					zoom_out(0.1)
