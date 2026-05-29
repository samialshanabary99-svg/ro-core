extends Node2D
class_name EntitySprite
## Base entity sprite class for all visible game entities
## Handles sprite rendering, animations, nameplates, and visual effects

# Entity data
var entity_id: int = 0
var entity_type: String = "player"  # player, npc, monster, item
var entity_name: String = ""
var job_id: int = 0
var direction: int = 0  # 0-7, 0=South, clockwise

# Visual components
var sprite: Sprite2D
var nameplate: Label
var shadow: Sprite2D
var animation_player: AnimationPlayer

# Animation state
var current_animation: String = "idle_s"
var is_moving: bool = false
var is_attacking: bool = false
var is_dead: bool = false

# Movement interpolation
var target_position: Vector2 = Vector2.ZERO
var move_speed: float = 200.0  # pixels per second
var is_interpolating: bool = false

# Direction names for animations
const DIRECTION_SUFFIXES := ["s", "sw", "w", "nw", "n", "ne", "e", "se"]

# Job sprite mappings (simplified for RO 2004)
const JOB_SPRITES := {
	0: "novice",
	1: "swordsman",
	2: "mage",
	3: "archer",
	4: "acolyte",
	5: "merchant",
	6: "thief"
}

# Monster sprite colors (for placeholder generation)
const MONSTER_COLORS := {
	1002: Color(0.8, 0.4, 0.2),   # Poring - orange
	1001: Color(0.6, 0.3, 0.1),   # Scorpion - brown  
	1003: Color(0.2, 0.6, 0.2),   # Fabre - green
	1004: Color(0.5, 0.5, 0.8),   # Lunatic - purple
}


func _ready() -> void:
	_setup_visual_components()
	_create_placeholder_sprite()


func _process(delta: float) -> void:
	if is_interpolating:
		_interpolate_movement(delta)
	
	_update_animation()
	_update_nameplate_position()


## Setup visual component nodes
func _setup_visual_components() -> void:
	# Shadow
	shadow = Sprite2D.new()
	shadow.name = "Shadow"
	shadow.modulate = Color(0, 0, 0, 0.3)
	shadow.z_index = -1
	add_child(shadow)
	
	# Main sprite
	sprite = Sprite2D.new()
	sprite.name = "Sprite"
	sprite.z_index = 0
	add_child(sprite)
	
	# Nameplate
	nameplate = Label.new()
	nameplate.name = "Nameplate"
	nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nameplate.add_theme_font_size_override("font_size", 10)
	nameplate.z_index = 10
	add_child(nameplate)
	
	# Animation player
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)
	
	_create_animations()


## Create placeholder sprite texture
func _create_placeholder_sprite() -> void:
	var img := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	var color := _get_entity_color()
	
	# Draw body (rectangle)
	for x in range(8, 24):
		for y in range(16, 48):
			img.set_pixel(x, y, color)
	
	# Draw head (circle-ish)
	var head_center := Vector2(16, 10)
	for x in range(32):
		for y in range(20):
			if Vector2(x, y).distance_to(head_center) < 8:
				img.set_pixel(x, y, color.lightened(0.2))
	
	# Draw direction indicator
	_draw_direction_indicator(img, color)
	
	var texture := ImageTexture.create_from_image(img)
	sprite.texture = texture
	sprite.offset = Vector2(0, -24)  # Anchor at feet
	
	# Create shadow
	var shadow_img := Image.create(24, 8, false, Image.FORMAT_RGBA8)
	for x in range(24):
		for y in range(8):
			var dist := Vector2(x, y).distance_to(Vector2(12, 4))
			if dist < 10:
				shadow_img.set_pixel(x, y, Color(0, 0, 0, 0.3 * (1.0 - dist / 10.0)))
	
	shadow.texture = ImageTexture.create_from_image(shadow_img)
	shadow.offset = Vector2(0, 0)


## Get color based on entity type
func _get_entity_color() -> Color:
	match entity_type:
		"player":
			# Color by job
			match job_id:
				0: return Color(0.9, 0.7, 0.5)  # Novice - beige
				1: return Color(0.8, 0.2, 0.2)  # Swordsman - red
				2: return Color(0.2, 0.2, 0.8)  # Mage - blue
				3: return Color(0.2, 0.8, 0.2)  # Archer - green
				4: return Color(0.9, 0.9, 0.5)  # Acolyte - yellow
				5: return Color(0.6, 0.4, 0.2)  # Merchant - brown
				6: return Color(0.5, 0.2, 0.5)  # Thief - purple
				_: return Color(0.7, 0.7, 0.7)
		"npc":
			return Color(0.3, 0.7, 0.9)  # NPCs are cyan
		"monster":
			return MONSTER_COLORS.get(entity_id, Color(0.8, 0.3, 0.3))
		"item":
			return Color(0.9, 0.8, 0.2)  # Items are gold
		_:
			return Color(0.7, 0.7, 0.7)


## Draw direction indicator on sprite
func _draw_direction_indicator(img: Image, base_color: Color) -> void:
	var indicator_color := base_color.darkened(0.3)
	var cx := 16
	var cy := 32
	
	match direction:
		0:  # South
			for x in range(14, 19):
				img.set_pixel(x, 44, indicator_color)
		1:  # Southwest
			for i in range(4):
				img.set_pixel(10 + i, 40 + i, indicator_color)
		2:  # West
			for y in range(30, 35):
				img.set_pixel(8, y, indicator_color)
		3:  # Northwest
			for i in range(4):
				img.set_pixel(10 + i, 34 - i, indicator_color)
		4:  # North
			for x in range(14, 19):
				img.set_pixel(x, 20, indicator_color)
		5:  # Northeast
			for i in range(4):
				img.set_pixel(22 - i, 34 - i, indicator_color)
		6:  # East
			for y in range(30, 35):
				img.set_pixel(24, y, indicator_color)
		7:  # Southeast
			for i in range(4):
				img.set_pixel(22 - i, 40 + i, indicator_color)


## Create basic animations
func _create_animations() -> void:
	var lib := AnimationLibrary.new()
	
	# Idle animation (subtle bob)
	var idle := Animation.new()
	idle.length = 1.0
	idle.loop_mode = Animation.LOOP_LINEAR
	
	var track_idx := idle.add_track(Animation.TYPE_VALUE)
	idle.track_set_path(track_idx, "Sprite:offset:y")
	idle.track_insert_key(track_idx, 0.0, -24)
	idle.track_insert_key(track_idx, 0.5, -25)
	idle.track_insert_key(track_idx, 1.0, -24)
	
	lib.add_animation("idle", idle)
	
	# Walk animation (bounce)
	var walk := Animation.new()
	walk.length = 0.4
	walk.loop_mode = Animation.LOOP_LINEAR
	
	track_idx = walk.add_track(Animation.TYPE_VALUE)
	walk.track_set_path(track_idx, "Sprite:offset:y")
	walk.track_insert_key(track_idx, 0.0, -24)
	walk.track_insert_key(track_idx, 0.1, -27)
	walk.track_insert_key(track_idx, 0.2, -24)
	walk.track_insert_key(track_idx, 0.3, -27)
	walk.track_insert_key(track_idx, 0.4, -24)
	
	lib.add_animation("walk", walk)
	
	# Attack animation (lunge forward)
	var attack := Animation.new()
	attack.length = 0.5
	attack.loop_mode = Animation.LOOP_NONE
	
	track_idx = attack.add_track(Animation.TYPE_VALUE)
	attack.track_set_path(track_idx, "Sprite:offset:x")
	attack.track_insert_key(track_idx, 0.0, 0)
	attack.track_insert_key(track_idx, 0.15, 8)
	attack.track_insert_key(track_idx, 0.5, 0)
	
	lib.add_animation("attack", attack)
	
	# Death animation (fall over)
	var death := Animation.new()
	death.length = 0.5
	death.loop_mode = Animation.LOOP_NONE
	
	track_idx = death.add_track(Animation.TYPE_VALUE)
	death.track_set_path(track_idx, "Sprite:rotation")
	death.track_insert_key(track_idx, 0.0, 0.0)
	death.track_insert_key(track_idx, 0.5, PI / 2)
	
	var alpha_track := death.add_track(Animation.TYPE_VALUE)
	death.track_set_path(alpha_track, "Sprite:modulate:a")
	death.track_insert_key(alpha_track, 0.0, 1.0)
	death.track_insert_key(alpha_track, 0.5, 0.5)
	
	lib.add_animation("death", death)
	
	# Hit animation (flash red)
	var hit := Animation.new()
	hit.length = 0.3
	hit.loop_mode = Animation.LOOP_NONE
	
	track_idx = hit.add_track(Animation.TYPE_VALUE)
	hit.track_set_path(track_idx, "Sprite:modulate")
	hit.track_insert_key(track_idx, 0.0, Color.WHITE)
	hit.track_insert_key(track_idx, 0.1, Color.RED)
	hit.track_insert_key(track_idx, 0.2, Color.WHITE)
	hit.track_insert_key(track_idx, 0.3, Color.WHITE)
	
	lib.add_animation("hit", hit)
	
	animation_player.add_animation_library("", lib)


## Initialize entity with data
func setup(id: int, type: String, name_str: String, pos: Vector2, job: int = 0) -> void:
	entity_id = id
	entity_type = type
	entity_name = name_str
	job_id = job
	position = pos
	target_position = pos
	
	nameplate.text = entity_name
	_create_placeholder_sprite()


## Update nameplate position
func _update_nameplate_position() -> void:
	nameplate.position = Vector2(-nameplate.size.x / 2, -60)


## Update animation based on state
func _update_animation() -> void:
	var anim_name := "idle"
	
	if is_dead:
		anim_name = "death"
	elif is_attacking:
		anim_name = "attack"
	elif is_moving or is_interpolating:
		anim_name = "walk"
	
	if animation_player.current_animation != anim_name:
		animation_player.play(anim_name)


## Set direction (0-7)
func set_direction(dir: int) -> void:
	direction = dir % 8
	_create_placeholder_sprite()  # Redraw with new direction indicator


## Calculate direction from movement vector
func direction_from_vector(vec: Vector2) -> int:
	if vec.length() < 0.1:
		return direction
	
	var angle := vec.angle()
	# Convert angle to 8-direction (0=South, clockwise)
	# angle: 0=right, PI/2=down, PI=left, -PI/2=up
	var dir_angle := fmod(angle + PI / 2 + PI / 8, TAU)
	return int(dir_angle / (TAU / 8)) % 8


## Move to target position with interpolation
func move_to(target: Vector2, speed: float = -1) -> void:
	if speed > 0:
		move_speed = speed
	
	var dir_vec := target - position
	set_direction(direction_from_vector(dir_vec))
	
	target_position = target
	is_interpolating = true
	is_moving = true


## Instantly teleport to position
func teleport_to(pos: Vector2) -> void:
	position = pos
	target_position = pos
	is_interpolating = false
	is_moving = false


## Interpolate movement
func _interpolate_movement(delta: float) -> void:
	var distance := position.distance_to(target_position)
	
	if distance < 1.0:
		position = target_position
		is_interpolating = false
		is_moving = false
		return
	
	var step := move_speed * delta
	position = position.move_toward(target_position, step)


## Play attack animation
func play_attack() -> void:
	is_attacking = true
	animation_player.play("attack")
	await animation_player.animation_finished
	is_attacking = false


## Play hit animation
func play_hit() -> void:
	animation_player.play("hit")


## Play death animation
func play_death() -> void:
	is_dead = true
	animation_player.play("death")


## Show damage number popup
func show_damage(amount: int, is_critical: bool = false) -> void:
	var damage_label := Label.new()
	damage_label.text = str(amount)
	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	if is_critical:
		damage_label.add_theme_font_size_override("font_size", 16)
		damage_label.add_theme_color_override("font_color", Color(1, 0.8, 0))
	else:
		damage_label.add_theme_font_size_override("font_size", 12)
		damage_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	
	damage_label.position = Vector2(-20, -70)
	add_child(damage_label)
	
	# Animate damage number floating up and fading
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(damage_label, "position:y", -100, 0.8)
	tween.tween_property(damage_label, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(damage_label.queue_free)


## Show heal number popup
func show_heal(amount: int) -> void:
	var heal_label := Label.new()
	heal_label.text = "+" + str(amount)
	heal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heal_label.add_theme_font_size_override("font_size", 12)
	heal_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
	heal_label.position = Vector2(-20, -70)
	add_child(heal_label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(heal_label, "position:y", -100, 0.8)
	tween.tween_property(heal_label, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(heal_label.queue_free)


## Clean up when entity is removed
func destroy() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
