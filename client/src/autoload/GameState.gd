extends Node
class_name GameStateAutoload
## GameState Autoload - Central state manager for the RO Core Client
## Stores all session, character, inventory, and world state
## Emits signals when state changes for UI and game systems to react

# =============================================================================
# SIGNALS
# =============================================================================

## Session lifecycle
signal session_started(token: String)
signal session_ended()

## Character state
signal character_selected(char_data: Dictionary)
signal stats_changed(stats: Dictionary)
signal exp_changed(base_exp: int, job_exp: int, base_next: int, job_next: int)
signal leveled_up(type: String, new_level: int)

## World state
signal entered_map(map_name: String, x: int, y: int)
signal entity_added(entity_id: String, data: Dictionary)
signal entity_removed(entity_id: String)
signal entity_updated(entity_id: String, data: Dictionary)

## Inventory
signal item_added(item_id: int, amount: int)
signal item_removed(item_id: int, amount: int)
signal inventory_changed(inventory: Array[Dictionary])

## Drops
signal drop_spawned(drop_uid: String, data: Dictionary)
signal drop_removed(drop_uid: String)

# =============================================================================
# CONSTANTS
# =============================================================================

const TILE_SIZE: int = 32
const DEFAULT_SERVER_URL: String = "ws://localhost:3000"

## Base stat formulas (RO 2004)
const BASE_HP: int = 40
const HP_PER_LEVEL: int = 5
const HP_PER_VIT: int = 2
const BASE_SP: int = 11
const SP_PER_LEVEL: int = 2
const SP_PER_INT: int = 2

# =============================================================================
# SESSION STATE
# =============================================================================

var session_token: String = ""
var is_authenticated: bool = false
var account_id: int = -1
var char_slots: Array[Dictionary] = []

# =============================================================================
# CHARACTER STATE
# =============================================================================

var char_id: int = -1
var char_name: String = ""
var job_id: int = 0  # 0 = Novice

var base_level: int = 1
var job_level: int = 1
var base_exp: int = 0
var job_exp: int = 0
var next_base_exp: int = 9
var next_job_exp: int = 9
var stat_points: int = 0

## Primary stats
var stat_str: int = 1
var stat_agi: int = 1
var stat_vit: int = 1
var stat_int: int = 1
var stat_dex: int = 1
var stat_luk: int = 1

## Derived stats (calculated from primary)
var hp: int = 40
var max_hp: int = 40
var sp: int = 11
var max_sp: int = 11
var atk: int = 2
var def: int = 0
var hit: int = 100
var flee: int = 1

# =============================================================================
# WORLD STATE
# =============================================================================

var current_map: String = ""
var player_x: int = 0
var player_y: int = 0
var player_direction: int = 0  # 0=down, 1=left, 2=up, 3=right
var player_entity_id: String = ""

## Entity cache: entity_id -> Dictionary with x, y, type, name, sprite, hp_percent, etc.
var entities: Dictionary = {}

## Drop cache: drop_uid -> Dictionary with item_id, x, y
var ground_drops: Dictionary = {}

# =============================================================================
# INVENTORY
# =============================================================================

var inventory: Array[Dictionary] = []
const MAX_INVENTORY: int = 100

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	print("[GameState] Autoload initialized")


## Reset all state to defaults (called on logout/disconnect)
func reset() -> void:
	session_token = ""
	is_authenticated = false
	account_id = -1
	char_slots.clear()
	
	char_id = -1
	char_name = ""
	job_id = 0
	base_level = 1
	job_level = 1
	base_exp = 0
	job_exp = 0
	next_base_exp = 9
	next_job_exp = 9
	stat_points = 0
	
	stat_str = 1
	stat_agi = 1
	stat_vit = 1
	stat_int = 1
	stat_dex = 1
	stat_luk = 1
	
	_recalculate_derived_stats()
	hp = max_hp
	sp = max_sp
	
	current_map = ""
	player_x = 0
	player_y = 0
	player_direction = 0
	player_entity_id = ""
	entities.clear()
	ground_drops.clear()
	inventory.clear()
	
	session_ended.emit()
	print("[GameState] State reset to defaults")

# =============================================================================
# SESSION METHODS
# =============================================================================

## Called after successful login packet
func set_session(token: String, slots: Array) -> void:
	session_token = token
	is_authenticated = true
	char_slots.clear()
	for slot in slots:
		if slot is Dictionary:
			char_slots.append(slot)
	session_started.emit(token)
	print("[GameState] Session established with %d character slots" % char_slots.size())


## Get character slot data by index
func get_char_slot(index: int) -> Dictionary:
	if index >= 0 and index < char_slots.size():
		return char_slots[index]
	return {}

# =============================================================================
# CHARACTER METHODS
# =============================================================================

## Load character data from server response
func load_character(data: Dictionary) -> void:
	char_id = data.get("id", -1)
	char_name = data.get("name", "Unknown")
	job_id = data.get("job_id", 0)
	
	base_level = data.get("base_level", 1)
	job_level = data.get("job_level", 1)
	base_exp = data.get("base_exp", 0)
	job_exp = data.get("job_exp", 0)
	next_base_exp = data.get("next_base_exp", 9)
	next_job_exp = data.get("next_job_exp", 9)
	stat_points = data.get("stat_points", 0)
	
	stat_str = data.get("str", 1)
	stat_agi = data.get("agi", 1)
	stat_vit = data.get("vit", 1)
	stat_int = data.get("int", 1)
	stat_dex = data.get("dex", 1)
	stat_luk = data.get("luk", 1)
	
	hp = data.get("hp", 40)
	sp = data.get("sp", 11)
	
	_recalculate_derived_stats()
	
	player_entity_id = str(char_id)
	character_selected.emit(data)
	stats_changed.emit(_get_stats_dict())
	print("[GameState] Character loaded: %s (Lv %d)" % [char_name, base_level])


## Update stats from server StatUpdate packet
func update_stats(data: Dictionary) -> void:
	if data.has("str"): stat_str = data["str"]
	if data.has("agi"): stat_agi = data["agi"]
	if data.has("vit"): stat_vit = data["vit"]
	if data.has("int"): stat_int = data["int"]
	if data.has("dex"): stat_dex = data["dex"]
	if data.has("luk"): stat_luk = data["luk"]
	
	if data.has("hp"): hp = data["hp"]
	if data.has("sp"): sp = data["sp"]
	if data.has("max_hp"): max_hp = data["max_hp"]
	if data.has("max_sp"): max_sp = data["max_sp"]
	
	if data.has("base_exp"): base_exp = data["base_exp"]
	if data.has("job_exp"): job_exp = data["job_exp"]
	if data.has("next_base_exp"): next_base_exp = data["next_base_exp"]
	if data.has("next_job_exp"): next_job_exp = data["next_job_exp"]
	if data.has("stat_points"): stat_points = data["stat_points"]
	
	_recalculate_derived_stats()
	stats_changed.emit(_get_stats_dict())
	exp_changed.emit(base_exp, job_exp, next_base_exp, next_job_exp)


## Handle level up from server
func handle_level_up(type: String, new_level: int) -> void:
	if type == "base":
		base_level = new_level
		stat_points += 1
	elif type == "job":
		job_level = new_level
	
	_recalculate_derived_stats()
	leveled_up.emit(type, new_level)
	stats_changed.emit(_get_stats_dict())
	print("[GameState] LEVEL UP! %s -> %d" % [type.to_upper(), new_level])


## Recalculate derived stats from primary stats
func _recalculate_derived_stats() -> void:
	max_hp = BASE_HP + (base_level * HP_PER_LEVEL) + (stat_vit * HP_PER_VIT)
	max_sp = BASE_SP + (base_level * SP_PER_LEVEL) + (stat_int * SP_PER_INT)
	atk = 2 + stat_str + int(pow(stat_str / 10.0, 2))
	def = 0  # Equipment-based, none for Milestone 1
	hit = 100 + stat_dex
	flee = 1 + stat_luk + stat_agi


## Build stats dictionary for signals
func _get_stats_dict() -> Dictionary:
	return {
		"str": stat_str, "agi": stat_agi, "vit": stat_vit,
		"int": stat_int, "dex": stat_dex, "luk": stat_luk,
		"hp": hp, "max_hp": max_hp, "sp": sp, "max_sp": max_sp,
		"atk": atk, "def": def, "hit": hit, "flee": flee,
		"base_level": base_level, "job_level": job_level,
		"base_exp": base_exp, "job_exp": job_exp,
		"next_base_exp": next_base_exp, "next_job_exp": next_job_exp,
		"stat_points": stat_points
	}

# =============================================================================
# WORLD METHODS
# =============================================================================

## Called when entering a new map
func enter_map(map_name: String, x: int, y: int) -> void:
	current_map = map_name
	player_x = x
	player_y = y
	entities.clear()
	ground_drops.clear()
	entered_map.emit(map_name, x, y)
	print("[GameState] Entered map: %s at (%d, %d)" % [map_name, x, y])


## Update local player position
func set_player_position(x: int, y: int, dir: int = -1) -> void:
	player_x = x
	player_y = y
	if dir >= 0:
		player_direction = dir


## Check if entity_id is the local player
func is_local_player(entity_id: String) -> bool:
	return entity_id == player_entity_id

# =============================================================================
# ENTITY CACHE
# =============================================================================

## Add or update an entity in the cache
func add_entity(entity_id: String, data: Dictionary) -> void:
	var is_new: bool = not entities.has(entity_id)
	entities[entity_id] = data
	if is_new:
		entity_added.emit(entity_id, data)
	else:
		entity_updated.emit(entity_id, data)


## Remove entity from cache
func remove_entity(entity_id: String) -> void:
	if entities.has(entity_id):
		entities.erase(entity_id)
		entity_removed.emit(entity_id)


## Get entity data by ID
func get_entity(entity_id: String) -> Dictionary:
	return entities.get(entity_id, {})


## Update entity position
func update_entity_position(entity_id: String, x: int, y: int, dir: int = -1) -> void:
	if entities.has(entity_id):
		entities[entity_id]["x"] = x
		entities[entity_id]["y"] = y
		if dir >= 0:
			entities[entity_id]["direction"] = dir
		entity_updated.emit(entity_id, entities[entity_id])

# =============================================================================
# DROP CACHE
# =============================================================================

## Add drop to ground
func add_drop(drop_uid: String, item_id: int, x: int, y: int) -> void:
	var data: Dictionary = {"item_id": item_id, "x": x, "y": y}
	ground_drops[drop_uid] = data
	drop_spawned.emit(drop_uid, data)


## Remove drop from ground
func remove_drop(drop_uid: String) -> void:
	if ground_drops.has(drop_uid):
		ground_drops.erase(drop_uid)
		drop_removed.emit(drop_uid)

# =============================================================================
# INVENTORY
# =============================================================================

## Add item to inventory (stacks if exists)
func add_item(item_id: int, amount: int) -> void:
	for i in range(inventory.size()):
		if inventory[i]["item_id"] == item_id:
			inventory[i]["amount"] += amount
			item_added.emit(item_id, amount)
			inventory_changed.emit(inventory)
			return
	
	if inventory.size() < MAX_INVENTORY:
		inventory.append({"item_id": item_id, "amount": amount})
		item_added.emit(item_id, amount)
		inventory_changed.emit(inventory)
		print("[GameState] Added to inventory: item %d x%d" % [item_id, amount])


## Get inventory item by item_id
func get_item_amount(item_id: int) -> int:
	for item in inventory:
		if item["item_id"] == item_id:
			return item["amount"]
	return 0
