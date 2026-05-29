## Phase 10 - Integration Testing
## Main game scene that ties all client components together
## This is the primary game world scene loaded after character selection

class_name GameWorld
extends Node2D

# Scene references
var map_loader: Node2D
var game_camera: Camera2D
var player_controller: Node2D
var player_entity: Node2D
var chat_box: Control
var stats_panel: Control
var hotbar: Control

# Entity container
var entities_container: Node2D

# Preload entity script
const EntitySprite = preload("res://src/entities/EntitySprite.gd")
const PlayerControllerScript = preload("res://src/entities/PlayerController.gd")

func _ready() -> void:
	_setup_world()
	_setup_ui()
	_connect_signals()
	_spawn_player()
	
	# Request initial game state from server
	if NetworkManager.is_socket_connected():
		print("[GameWorld] Connected to server, requesting map data")
	else:
		print("[GameWorld] Running in offline mode")
		_load_default_map()

func _setup_world() -> void:
	# Create map loader
	var MapLoaderScript = load("res://src/world/MapLoader.gd")
	map_loader = Node2D.new()
	map_loader.set_script(MapLoaderScript)
	map_loader.name = "MapLoader"
	add_child(map_loader)
	
	# Create entities container
	entities_container = Node2D.new()
	entities_container.name = "Entities"
	add_child(entities_container)
	
	# Create camera
	var CameraScript = load("res://src/world/Camera2D.gd")
	game_camera = Camera2D.new()
	game_camera.set_script(CameraScript)
	game_camera.name = "GameCamera"
	add_child(game_camera)

func _setup_ui() -> void:
	# Create UI layer
	var ui_layer := CanvasLayer.new()
	ui_layer.name = "UILayer"
	ui_layer.layer = 10
	add_child(ui_layer)
	
	# Create chat box
	var ChatBoxScript = load("res://src/ui/ChatBox.gd")
	chat_box = Control.new()
	chat_box.set_script(ChatBoxScript)
	chat_box.name = "ChatBox"
	ui_layer.add_child(chat_box)
	
	# Create stats panel
	var StatsPanelScript = load("res://src/ui/StatsPanel.gd")
	stats_panel = Control.new()
	stats_panel.set_script(StatsPanelScript)
	stats_panel.name = "StatsPanel"
	ui_layer.add_child(stats_panel)
	
	# Create hotbar
	var HotbarScript = load("res://src/ui/Hotbar.gd")
	hotbar = Control.new()
	hotbar.set_script(HotbarScript)
	hotbar.name = "Hotbar"
	ui_layer.add_child(hotbar)

func _connect_signals() -> void:
	# GameState signals
	GameState.entity_spawned.connect(_on_entity_spawned)
	GameState.entity_despawned.connect(_on_entity_despawned)
	GameState.entity_moved.connect(_on_entity_moved)
	GameState.map_changed.connect(_on_map_changed)
	
	# PacketHandler signals for direct packet events
	PacketHandler.map_data_received.connect(_on_map_data_received)
	PacketHandler.entity_spawn_received.connect(_on_entity_spawn_received)
	PacketHandler.entity_despawn_received.connect(_on_entity_despawn_received)

func _load_default_map() -> void:
	# Load default test map
	map_loader.load_default_map()
	
	# Update camera bounds
	var map_size := map_loader.get_map_size()
	var tile_size := map_loader.tile_size
	game_camera.set_bounds(Rect2(
		Vector2.ZERO,
		Vector2(map_size.x * tile_size, map_size.y * tile_size)
	))

func _spawn_player() -> void:
	# Create player entity
	player_entity = Node2D.new()
	player_entity.set_script(EntitySprite)
	player_entity.name = "Player"
	entities_container.add_child(player_entity)
	
	# Initialize player with character data
	var char_data := GameState.current_character
	if char_data.is_empty():
		# Use default test data
		char_data = {
			"id": 1,
			"name": "TestPlayer",
			"job_id": 0,
			"base_level": 1,
			"job_level": 1
		}
	
	player_entity.initialize({
		"entity_id": GameState.session.get("account_id", 1),
		"entity_type": "player",
		"name": char_data.get("name", "Player"),
		"job_id": char_data.get("job_id", 0),
		"position": map_loader.get_spawn_point()
	})
	
	# Create player controller
	player_controller = Node2D.new()
	player_controller.set_script(PlayerControllerScript)
	player_controller.name = "PlayerController"
	player_entity.add_child(player_controller)
	
	# Initialize controller with references
	player_controller.initialize(player_entity, map_loader)
	
	# Set camera target
	game_camera.set_target(player_entity)
	
	print("[GameWorld] Player spawned at ", player_entity.position)

func _on_entity_spawned(entity_id: int, data: Dictionary) -> void:
	# Don't spawn duplicate of player
	if entity_id == GameState.session.get("account_id", -1):
		return
	
	# Create entity sprite
	var entity := Node2D.new()
	entity.set_script(EntitySprite)
	entity.name = "Entity_%d" % entity_id
	entities_container.add_child(entity)
	
	entity.initialize(data)
	print("[GameWorld] Entity spawned: ", entity_id)

func _on_entity_despawned(entity_id: int) -> void:
	var entity_name := "Entity_%d" % entity_id
	var entity := entities_container.get_node_or_null(entity_name)
	if entity:
		entity.queue_free()
		print("[GameWorld] Entity despawned: ", entity_id)

func _on_entity_moved(entity_id: int, from_pos: Vector2, to_pos: Vector2) -> void:
	# Find entity and move it
	var entity_name := "Entity_%d" % entity_id
	var entity := entities_container.get_node_or_null(entity_name)
	if entity and entity.has_method("move_to"):
		entity.move_to(to_pos)

func _on_map_changed(map_name: String) -> void:
	print("[GameWorld] Map change requested: ", map_name)
	# Clear existing entities
	for child in entities_container.get_children():
		if child != player_entity:
			child.queue_free()
	
	# Request new map data
	NetworkManager.send_map_loaded(map_name)

func _on_map_data_received(data: Dictionary) -> void:
	print("[GameWorld] Map data received")
	map_loader.load_from_data(data)
	
	# Update camera bounds
	var map_size := map_loader.get_map_size()
	var tile_size := map_loader.tile_size
	game_camera.set_bounds(Rect2(
		Vector2.ZERO,
		Vector2(map_size.x * tile_size, map_size.y * tile_size)
	))

func _on_entity_spawn_received(data: Dictionary) -> void:
	var entity_id: int = data.get("entity_id", 0)
	_on_entity_spawned(entity_id, data)

func _on_entity_despawn_received(entity_id: int) -> void:
	_on_entity_despawned(entity_id)

# Public API for other systems
func get_player() -> Node2D:
	return player_entity

func get_player_controller() -> Node2D:
	return player_controller

func get_entity(entity_id: int) -> Node2D:
	var entity_name := "Entity_%d" % entity_id
	return entities_container.get_node_or_null(entity_name)

func get_all_entities() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for child in entities_container.get_children():
		result.append(child)
	return result
