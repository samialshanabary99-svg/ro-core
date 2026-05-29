extends Node2D

@onready var map_renderer = $MapRenderer
@onready var remote_entities_layer = $EntityLayer/RemoteEntities
@onready var drop_layer = $DropLayer

const ENTITY_RENDERER_TEMPLATE = preload("res://scenes/entities/EntityRenderer.tscn")
const DROP_ENTITY_TEMPLATE = preload("res://scenes/entities/DropEntity.tscn")
const DAMAGE_NUMBER_TEMPLATE = preload("res://scenes/ui/DamageNumber.tscn")

func _ready() -> void:
	NetworkManager.entity_spawn.connect(_on_entity_spawn)
	NetworkManager.entity_despawn.connect(_on_entity_despawn)
	NetworkManager.walk_notify.connect(_on_walk_notify)
	NetworkManager.damage_notify.connect(_on_damage_notify)
	NetworkManager.entity_death.connect(_on_entity_death)

func _on_entity_spawn(data: Dictionary) -> void:
	var spawned_id = data.id
	
	if spawned_id == "char_" + GameState.player_id:
		if GameState.local_player_node:
			GameState.local_player_node.position = Vector2(data.x * 32, data.y * 32)
			GameState.local_player_node.get_node("EntityRenderer").setup(data, false)
		return
		
	if remote_entities_layer.has_node(spawned_id):
		return

	var remote_instance = ENTITY_RENDERER_TEMPLATE.instantiate()
	remote_entities_layer.add_child(remote_instance)
	remote_instance.name = spawned_id
	remote_instance.setup(data, true)

func _on_entity_despawn(entity_id: String) -> void:
	if remote_entities_layer.has_node(entity_id):
		remote_entities_layer.get_node(entity_id).queue_free()

func _on_walk_notify(data: Dictionary) -> void:
	var entity_id = data.id
	if remote_entities_layer.has_node(entity_id):
		var target_node = remote_entities_layer.get_node(entity_id)
		target_node.sync_movement(data.x, data.y, data.dir)

func _on_damage_notify(data: Dictionary) -> void:
	var target_id = data.target_id
	var dmg = data.damage
	var is_crit = data.get("is_crit", false)
	
	var target_pos: Vector2 = Vector2.ZERO
	
	if remote_entities_layer.has_node(target_id):
		var target_node = remote_entities_layer.get_node(target_id)
		target_node.update_hp(data.hp_left)
		target_node.play_action("hit")
		target_pos = target_node.position
	elif GameState.local_player_node and target_id == "char_" + GameState.player_id:
		var p_render = GameState.local_player_node.get_node("EntityRenderer")
		p_render.update_hp(data.hp_left)
		p_render.play_action("hit")
		target_pos = GameState.local_player_node.position
		
	if target_pos != Vector2.ZERO:
		_spawn_damage_text(target_pos, dmg, is_crit)

func _spawn_damage_text(pos: Vector2, amt: int, crit: bool) -> void:
	var d_lbl = DAMAGE_NUMBER_TEMPLATE.instantiate()
	add_child(d_lbl)
	d_lbl.display_damage(pos, amt, crit)

func _on_entity_death(data: Dictionary) -> void:
	var target_id = data.id
	if remote_entities_layer.has_node(target_id):
		remote_entities_layer.get_node(target_id).process_death()
		
	var drops = data.get("drops", [])
	for drop in drops:
		var drop_node = DROP_ENTITY_TEMPLATE.instantiate()
		drop_layer.add_child(drop_node)
		drop_node.setup(drop)