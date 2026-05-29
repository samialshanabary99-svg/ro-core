extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var name_label: Label = $NameLabel
@onready var hp_bar: TextureProgressBar = $HPBar

var entity_id: String
var entity_type: String
var target_grid_pos: Vector2
var is_remote: bool = false

var _interp_speed: float = 15.0

func setup(data: Dictionary, remote: bool = false) -> void:
	entity_id = data.id
	entity_type = data.entity_type
	is_remote = remote
	
	name_label.text = data.get("name", "Unknown")
	position = Vector2(data.get("x", 0) * 32, data.get("y", 0) * 32)
	target_grid_pos = position
	
	var asset_key: String = data.get("sprite", "novice")
	sprite.sprite_frames = SpriteLoader.load_sprite(asset_key, entity_type)
	sprite.play("idle")
	
	update_hp(data.get("hp_percent", 100))

func update_hp(percent: int) -> void:
	hp_bar.value = percent
	hp_bar.visible = (percent < 100 and percent > 0)

func sync_movement(grid_x: int, grid_y: int, dir: int) -> void:
	target_grid_pos = Vector2(grid_x * 32, grid_y * 32)
	_update_direction_facing(dir)
	if sprite.animation != "walk" and sprite.animation != "attack":
		sprite.play("walk")

func _update_direction_facing(dir: int) -> void:
	match dir:
		1: sprite.flip_h = true
		2: sprite.flip_h = false

func play_action(anim_name: String) -> void:
	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
		if not sprite.sprite_frames.get_animation_loop(anim_name):
			await sprite.animation_finished
			if sprite.animation == anim_name:
				sprite.play("idle")

func process_death() -> void:
	play_action("dead")
	set_physics_process(false)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	await tween.finished
	queue_free()

func _physics_process(delta: float) -> void:
	if is_remote:
		position = position.lerp(target_grid_pos, _interp_speed * delta)
		if position.distance_to(target_grid_pos) < 1.0:
			position = target_grid_pos
			if sprite.animation == "walk":
				sprite.play("idle")