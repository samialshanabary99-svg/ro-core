extends Node
class_name PacketHandlerAutoload
## PacketHandler Autoload - Routes incoming packets to game systems
## Listens to NetworkManager.packet_received and dispatches to GameState + UI signals

# =============================================================================
# SIGNALS - For game systems and UI to connect to
# =============================================================================

## Authentication
signal login_succeeded(token: String, char_slots: Array)
signal login_failed(reason: String)

## Character Selection
signal char_list_received(char_list: Array)
signal char_created(char_data: Dictionary)
signal char_deleted(char_id: int)
signal char_select_result(success: bool, data: Dictionary)

## Map/World
signal map_data_received(data: Dictionary)
signal entity_spawn_received(data: Dictionary)
signal entity_despawn_received(entity_id: int)
signal map_entered(map_name: String, x: int, y: int)

## Entities
signal entity_spawned(entity_id: String, data: Dictionary)
signal entity_despawned(entity_id: String)
signal entity_moved(entity_id: String, x: int, y: int, direction: int)
signal entity_stopped(entity_id: String, x: int, y: int)

## Combat
signal damage_received(attacker_id: String, target_id: String, damage: int, is_crit: bool, hp_left: int)
signal entity_died(entity_id: String, drops: Array)

## Items
signal pickup_result(item_id: int, amount: int, success: bool)

## Stats
signal stats_updated(data: Dictionary)
signal level_up_received(type: String, new_level: int)

## Chat
signal chat_message_received(sender_id: String, message: String, scope: String)

## Errors
signal server_error(message: String)

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	NetworkManager.packet_received.connect(_on_packet_received)
	NetworkManager.connected_to_server.connect(_on_connected)
	NetworkManager.disconnected_from_server.connect(_on_disconnected)
	print("[PacketHandler] Autoload initialized, listening to NetworkManager")


func _on_connected() -> void:
	print("[PacketHandler] Server connection established")


func _on_disconnected() -> void:
	print("[PacketHandler] Server connection lost")

# =============================================================================
# PACKET ROUTING
# =============================================================================

func _on_packet_received(pid: String, payload: Dictionary) -> void:
	match pid:
		NetworkManager.PID_LOGIN_SUCCESS:
			_handle_login_success(payload)
		
		NetworkManager.PID_LOGIN_FAILED:
			_handle_login_failed(payload)
		
		NetworkManager.PID_ENTER_MAP:
			_handle_enter_map(payload)
		
		NetworkManager.PID_ENTITY_SPAWN:
			_handle_entity_spawn(payload)
		
		NetworkManager.PID_ENTITY_DESPAWN:
			_handle_entity_despawn(payload)
		
		NetworkManager.PID_WALK_NOTIFY:
			_handle_walk_notify(payload)
		
		NetworkManager.PID_STOP_MOVE:
			_handle_stop_move(payload)
		
		NetworkManager.PID_DAMAGE_NOTIFY:
			_handle_damage_notify(payload)
		
		NetworkManager.PID_ENTITY_DEATH:
			_handle_entity_death(payload)
		
		NetworkManager.PID_PICKUP_NOTIFY:
			_handle_pickup_notify(payload)
		
		NetworkManager.PID_STAT_UPDATE:
			_handle_stat_update(payload)
		
		NetworkManager.PID_LEVEL_UP:
			_handle_level_up(payload)
		
		NetworkManager.PID_CHAT_MESSAGE:
			_handle_chat_message(payload)
		
		NetworkManager.PID_SERVER_ERROR:
			_handle_server_error(payload)
		
		_:
			print("[PacketHandler] Unhandled packet: %s" % pid)

# =============================================================================
# PACKET HANDLERS
# =============================================================================

## 0x0065 - Login Success
func _handle_login_success(payload: Dictionary) -> void:
	var token: String = payload.get("session_token", "")
	var slots: Array = payload.get("char_slots", [])
	
	GameState.set_session(token, slots)
	login_succeeded.emit(token, slots)
	print("[PacketHandler] Login successful, %d character(s)" % slots.size())


## 0x0066 - Login Failed
func _handle_login_failed(payload: Dictionary) -> void:
	var reason: String = payload.get("reason", "Unknown error")
	login_failed.emit(reason)
	print("[PacketHandler] Login failed: %s" % reason)


## 0x0072 - Enter Map
func _handle_enter_map(payload: Dictionary) -> void:
	var map_name: String = payload.get("map_name", "")
	var x: int = payload.get("x", 0)
	var y: int = payload.get("y", 0)
	var char_data: Dictionary = payload.get("char_data", {})
	
	if not char_data.is_empty():
		GameState.load_character(char_data)
	
	GameState.enter_map(map_name, x, y)
	map_entered.emit(map_name, x, y)


## 0x0078 - Entity Spawn
func _handle_entity_spawn(payload: Dictionary) -> void:
	var entity_id: String = str(payload.get("id", ""))
	var data: Dictionary = {
		"id": entity_id,
		"entity_type": payload.get("entity_type", "unknown"),
		"name": payload.get("name", ""),
		"sprite": payload.get("sprite", "novice"),
		"x": payload.get("x", 0),
		"y": payload.get("y", 0),
		"direction": payload.get("dir", 0),
		"speed": payload.get("speed", 200),
		"hp_percent": payload.get("hp_percent", 100)
	}
	
	GameState.add_entity(entity_id, data)
	entity_spawned.emit(entity_id, data)
	print("[PacketHandler] Spawned %s: %s at (%d, %d)" % [
		data["entity_type"], data["name"], data["x"], data["y"]
	])


## 0x0080 - Entity Despawn
func _handle_entity_despawn(payload: Dictionary) -> void:
	var entity_id: String = str(payload.get("id", ""))
	GameState.remove_entity(entity_id)
	entity_despawned.emit(entity_id)


## 0x0086 - Walk Notify
func _handle_walk_notify(payload: Dictionary) -> void:
	var entity_id: String = str(payload.get("id", ""))
	var x: int = payload.get("x", 0)
	var y: int = payload.get("y", 0)
	var dir: int = payload.get("dir", 0)
	
	GameState.update_entity_position(entity_id, x, y, dir)
	
	if GameState.is_local_player(entity_id):
		GameState.set_player_position(x, y, dir)
	
	entity_moved.emit(entity_id, x, y, dir)


## 0x0087 - Stop Move
func _handle_stop_move(payload: Dictionary) -> void:
	var entity_id: String = str(payload.get("id", ""))
	var x: int = payload.get("x", 0)
	var y: int = payload.get("y", 0)
	
	GameState.update_entity_position(entity_id, x, y)
	
	if GameState.is_local_player(entity_id):
		GameState.set_player_position(x, y)
	
	entity_stopped.emit(entity_id, x, y)


## 0x0089 - Damage Notify
func _handle_damage_notify(payload: Dictionary) -> void:
	var attacker_id: String = str(payload.get("attacker_id", ""))
	var target_id: String = str(payload.get("target_id", ""))
	var damage: int = payload.get("damage", 0)
	var is_crit: bool = payload.get("is_crit", false)
	var hp_left: int = payload.get("hp_left", 0)
	
	# Update entity HP in cache
	var entity: Dictionary = GameState.get_entity(target_id)
	if not entity.is_empty():
		entity["hp_percent"] = hp_left
		GameState.add_entity(target_id, entity)
	
	damage_received.emit(attacker_id, target_id, damage, is_crit, hp_left)
	print("[PacketHandler] %s dealt %d%s damage to %s (HP: %d)" % [
		attacker_id, damage, " CRIT!" if is_crit else "", target_id, hp_left
	])


## 0x0090 - Entity Death
func _handle_entity_death(payload: Dictionary) -> void:
	var entity_id: String = str(payload.get("id", ""))
	var drops: Array = payload.get("drops", [])
	
	# Add drops to GameState
	for drop in drops:
		var drop_uid: String = str(drop.get("uid", ""))
		var item_id: int = drop.get("item_id", 0)
		var x: int = drop.get("x", 0)
		var y: int = drop.get("y", 0)
		GameState.add_drop(drop_uid, item_id, x, y)
	
	entity_died.emit(entity_id, drops)
	print("[PacketHandler] Entity %s died, dropped %d item(s)" % [entity_id, drops.size()])


## 0x0092 - Pickup Notify
func _handle_pickup_notify(payload: Dictionary) -> void:
	var item_id: int = payload.get("item_id", 0)
	var amount: int = payload.get("amount", 0)
	var result: String = payload.get("result", "fail")
	var drop_uid: String = str(payload.get("drop_uid", ""))
	
	var success: bool = result == "success"
	if success:
		GameState.add_item(item_id, amount)
		GameState.remove_drop(drop_uid)
	
	pickup_result.emit(item_id, amount, success)
	print("[PacketHandler] Pickup %s: item %d x%d" % [result, item_id, amount])


## 0x0094 - Stat Update
func _handle_stat_update(payload: Dictionary) -> void:
	GameState.update_stats(payload)
	stats_updated.emit(payload)


## 0x0095 - Level Up
func _handle_level_up(payload: Dictionary) -> void:
	var type: String = payload.get("type", "base")
	var new_level: int = payload.get("new_level", 1)
	
	GameState.handle_level_up(type, new_level)
	level_up_received.emit(type, new_level)


## 0x0093 - Chat Message
func _handle_chat_message(payload: Dictionary) -> void:
	var sender_id: String = str(payload.get("sender_id", ""))
	var message: String = payload.get("message", "")
	var scope: String = payload.get("scope", "map")
	
	chat_message_received.emit(sender_id, message, scope)


## 0x00FF - Server Error
func _handle_server_error(payload: Dictionary) -> void:
	var message: String = payload.get("message", "Unknown server error")
	server_error.emit(message)
	push_error("[PacketHandler] Server error: %s" % message)
