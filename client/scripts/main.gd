extends Node

@onready var login_screen = $LoginScreen
@onready var char_select = $CharSelect
@onready var game_world = $GameWorld

func _ready() -> void:
	_switch_layer_context("login")
	NetworkManager.login_success.connect(_on_login_success)
	NetworkManager.enter_map.connect(_on_enter_map)

func _switch_layer_context(target_context: String) -> void:
	login_screen.visible = (target_context == "login")
	char_select.visible = (target_context == "char_select")
	game_world.visible = (target_context == "game")
	
	if target_context == "game":
		GameState.input_mode = "game"
	else:
		GameState.input_mode = "ui"

func _on_login_success(data: Dictionary) -> void:
	_switch_layer_context("char_select")
	var chars = data.get("characters", [])
	if chars.size() > 0:
		GameState.player_id = str(chars[0].id)
		GameState.player_name = chars[0].name

func _on_enter_world_pressed() -> void:
	if not GameState.player_id.is_empty():
		NetworkManager.send_char_select(GameState.player_id.to_int())

func _on_enter_map(data: Dictionary) -> void:
	GameState.current_map = data.get("map_name", "prt_fild01")
	
	var world_map_node = game_world.get_node("MapRenderer")
	if world_map_node:
		world_map_node.load_map(data)
		
	_switch_layer_context("game")