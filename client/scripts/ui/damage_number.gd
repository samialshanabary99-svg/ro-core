extends Label

func display_damage(start_pos: Vector2, amount: int, is_crit: bool) -> void:
	global_position = start_pos + Vector2(randf_range(-8, 8), -16)
	text = "Miss" if amount == 0 else str(amount)
	
	if amount == 0:
		add_theme_color_override("font_color", Color.LIGHT_GRAY)
	elif is_crit:
		add_theme_color_override("font_color", Color.RED)
		add_theme_font_size_override("font_size", 24)
	else:
		add_theme_color_override("font_color", Color.WHITE)
		
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "global_position:y", global_position.y - 48, 0.8)
	tween.tween_property(self, "modulate:a", 0.0, 0.8).set_delay(0.2)
	tween.chain().tween_callback(queue_free)