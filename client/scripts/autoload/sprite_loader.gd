extends Node

func load_sprite(sprite_name: String, sprite_type: String) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	
	match sprite_type:
		"player":
			_generate_fallback_frames(frames, Color.DARK_BLUE, sprite_name)
		"monster":
			_generate_fallback_frames(frames, Color.DEEP_PINK, sprite_name)
		"drop":
			_generate_fallback_frames(frames, Color.GOLD, sprite_name)
		_:
			_generate_fallback_frames(frames, Color.SLATE_GRAY, "unknown")
	
	return frames

func load_drop_icon(item_id: int) -> Texture2D:
	var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	match item_id:
		909: img.fill(Color.GOLD)
		512: img.fill(Color.RED)
		_: img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)

func _generate_fallback_frames(frames: SpriteFrames, fill_color: Color, anim_profile: String) -> void:
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(fill_color)
	var tex: Texture2D = ImageTexture.create_from_image(img)
	
	var animations = ["idle", "walk", "attack", "dead", "hit"]
	for anim in animations:
		if not frames.has_animation(anim):
			frames.add_animation(anim)
		frames.add_frame(anim, tex)
		frames.set_animation_speed(anim, 5.0)
		frames.set_animation_loop(anim, true if anim in ["idle", "walk"] else false)