## HotbarSlot.gd - RO 2004 style hotbar slot for skills/items
## Individual slot that can hold a skill or item with cooldown display
extends Control
class_name HotbarSlot

## Slot content type
enum SlotType {
	EMPTY = 0,
	SKILL = 1,
	ITEM = 2
}

## Slot data
@export var slot_index: int = 0
@export var hotkey: String = ""

## Current content
var slot_type: SlotType = SlotType.EMPTY
var content_id: int = -1
var content_name: String = ""
var cooldown_remaining: float = 0.0
var cooldown_total: float = 0.0
var item_count: int = 0

## UI elements
var background: Panel
var icon: TextureRect
var cooldown_overlay: ColorRect
var cooldown_label: Label
var hotkey_label: Label
var count_label: Label

## Style
const SLOT_SIZE := Vector2(40, 40)
const BG_COLOR := Color(0.15, 0.15, 0.2, 0.9)
const BG_HOVER := Color(0.25, 0.25, 0.3, 0.9)
const BG_ACTIVE := Color(0.3, 0.3, 0.4, 0.9)
const BORDER_COLOR := Color(0.4, 0.35, 0.3)
const COOLDOWN_COLOR := Color(0.0, 0.0, 0.0, 0.7)

## Signals
signal slot_pressed(slot_index: int)
signal slot_right_clicked(slot_index: int)
signal item_dropped(slot_index: int, item_data: Dictionary)


func _ready() -> void:
	_setup_ui()


func _setup_ui() -> void:
	custom_minimum_size = SLOT_SIZE
	size = SLOT_SIZE
	
	# Background panel
	background = Panel.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	background.add_theme_stylebox_override("panel", style)
	add_child(background)
	
	# Icon texture
	icon = TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 4
	icon.offset_top = 4
	icon.offset_right = -4
	icon.offset_bottom = -4
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.visible = false
	add_child(icon)
	
	# Cooldown overlay
	cooldown_overlay = ColorRect.new()
	cooldown_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	cooldown_overlay.color = COOLDOWN_COLOR
	cooldown_overlay.visible = false
	cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cooldown_overlay)
	
	# Cooldown text
	cooldown_label = Label.new()
	cooldown_label.set_anchors_preset(Control.PRESET_CENTER)
	cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cooldown_label.add_theme_font_size_override("font_size", 12)
	cooldown_label.visible = false
	add_child(cooldown_label)
	
	# Hotkey label (top-left)
	hotkey_label = Label.new()
	hotkey_label.position = Vector2(2, 0)
	hotkey_label.add_theme_font_size_override("font_size", 10)
	hotkey_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	hotkey_label.text = hotkey
	add_child(hotkey_label)
	
	# Item count label (bottom-right)
	count_label = Label.new()
	count_label.anchor_left = 1.0
	count_label.anchor_top = 1.0
	count_label.anchor_right = 1.0
	count_label.anchor_bottom = 1.0
	count_label.offset_left = -20
	count_label.offset_top = -16
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_font_size_override("font_size", 10)
	count_label.visible = false
	add_child(count_label)
	
	# Enable mouse interaction
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_pressed()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			slot_right_clicked.emit(slot_index)


func _process(delta: float) -> void:
	if cooldown_remaining > 0:
		cooldown_remaining -= delta
		if cooldown_remaining <= 0:
			cooldown_remaining = 0
			_update_cooldown_display()
		else:
			_update_cooldown_display()


## Set slot content to a skill
func set_skill(skill_id: int, skill_name: String, skill_icon: Texture2D = null) -> void:
	slot_type = SlotType.SKILL
	content_id = skill_id
	content_name = skill_name
	
	if skill_icon:
		icon.texture = skill_icon
	else:
		icon.texture = _create_placeholder_skill_icon(skill_id)
	
	icon.visible = true
	count_label.visible = false


## Set slot content to an item
func set_item(item_id: int, item_name: String, count: int, item_icon: Texture2D = null) -> void:
	slot_type = SlotType.ITEM
	content_id = item_id
	content_name = item_name
	item_count = count
	
	if item_icon:
		icon.texture = item_icon
	else:
		icon.texture = _create_placeholder_item_icon(item_id)
	
	icon.visible = true
	count_label.text = str(count) if count > 1 else ""
	count_label.visible = count > 1


## Update item count
func update_count(count: int) -> void:
	if slot_type != SlotType.ITEM:
		return
	
	item_count = count
	count_label.text = str(count) if count > 1 else ""
	count_label.visible = count > 1
	
	if count <= 0:
		clear_slot()


## Clear the slot
func clear_slot() -> void:
	slot_type = SlotType.EMPTY
	content_id = -1
	content_name = ""
	item_count = 0
	cooldown_remaining = 0
	cooldown_total = 0
	
	icon.visible = false
	count_label.visible = false
	cooldown_overlay.visible = false
	cooldown_label.visible = false


## Start cooldown animation
func start_cooldown(duration: float) -> void:
	cooldown_total = duration
	cooldown_remaining = duration
	cooldown_overlay.visible = true
	cooldown_label.visible = true
	_update_cooldown_display()


## Check if on cooldown
func is_on_cooldown() -> bool:
	return cooldown_remaining > 0


## Set the hotkey display text
func set_hotkey_text(text: String) -> void:
	hotkey = text
	hotkey_label.text = text


func _update_cooldown_display() -> void:
	if cooldown_remaining <= 0:
		cooldown_overlay.visible = false
		cooldown_label.visible = false
		return
	
	# Update overlay height (fills from bottom to top as cooldown progresses)
	var progress := cooldown_remaining / cooldown_total
	cooldown_overlay.anchor_top = 1.0 - progress
	cooldown_overlay.offset_top = 0
	
	# Update text
	if cooldown_remaining >= 1.0:
		cooldown_label.text = "%d" % ceil(cooldown_remaining)
	else:
		cooldown_label.text = "%.1f" % cooldown_remaining


func _create_placeholder_skill_icon(skill_id: int) -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	
	# Use skill_id to generate a color
	var hue := fmod(float(skill_id) * 0.15, 1.0)
	var color := Color.from_hsv(hue, 0.6, 0.8)
	
	# Fill with gradient
	for y in range(32):
		for x in range(32):
			var brightness := 1.0 - (float(y) / 32.0 * 0.3)
			var c := Color(color.r * brightness, color.g * brightness, color.b * brightness)
			
			# Add border
			if x == 0 or x == 31 or y == 0 or y == 31:
				c = c.darkened(0.3)
			
			img.set_pixel(x, y, c)
	
	# Draw a simple symbol in center
	var symbol_color := Color.WHITE.darkened(0.1)
	for i in range(8, 24):
		img.set_pixel(i, 15, symbol_color)
		img.set_pixel(i, 16, symbol_color)
		img.set_pixel(15, i, symbol_color)
		img.set_pixel(16, i, symbol_color)
	
	return ImageTexture.create_from_image(img)


func _create_placeholder_item_icon(item_id: int) -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	
	# Use item_id to generate a color
	var hue := fmod(float(item_id) * 0.1, 1.0)
	var color := Color.from_hsv(hue, 0.5, 0.7)
	
	# Draw a simple potion/item shape
	for y in range(32):
		for x in range(32):
			var dx := x - 16
			var dy := y - 16
			var dist := sqrt(dx * dx + dy * dy)
			
			# Circular item shape
			if dist < 12:
				var brightness := 1.0 - (dist / 12.0 * 0.2)
				img.set_pixel(x, y, Color(color.r * brightness, color.g * brightness, color.b * brightness))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	
	return ImageTexture.create_from_image(img)


func _on_pressed() -> void:
	if slot_type == SlotType.EMPTY:
		return
	
	if cooldown_remaining > 0:
		return
	
	slot_pressed.emit(slot_index)
	
	# Visual feedback
	var tween := create_tween()
	modulate = Color(1.3, 1.3, 1.3)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)


func _on_mouse_entered() -> void:
	var style := background.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		var hover_style := style.duplicate() as StyleBoxFlat
		hover_style.bg_color = BG_HOVER
		background.add_theme_stylebox_override("panel", hover_style)
	
	# Show tooltip
	if content_name != "":
		tooltip_text = content_name


func _on_mouse_exited() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	background.add_theme_stylebox_override("panel", style)
