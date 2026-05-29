## Hotbar.gd - RO 2004 style hotbar container
## Contains multiple HotbarSlot instances and handles input
extends Control
class_name Hotbar

## Settings
@export var num_slots: int = 9
@export var slot_spacing: int = 4

## References
var slots: Array[HotbarSlot] = []
var container: HBoxContainer
var background: Panel

## Hotkey mappings
var hotkeys := ["1", "2", "3", "4", "5", "6", "7", "8", "9"]

## Signals
signal skill_activated(skill_id: int)
signal item_used(item_id: int)


func _ready() -> void:
	_setup_ui()
	_connect_signals()


func _setup_ui() -> void:
	# Position at bottom center
	anchor_left = 0.5
	anchor_top = 1.0
	anchor_right = 0.5
	anchor_bottom = 1.0
	
	var total_width := num_slots * 40 + (num_slots - 1) * slot_spacing + 16
	offset_left = -total_width / 2
	offset_right = total_width / 2
	offset_top = -60
	offset_bottom = -10
	
	# Background
	background = Panel.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.85)
	style.border_color = Color(0.3, 0.3, 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	background.add_theme_stylebox_override("panel", style)
	add_child(background)
	
	# Slot container
	container = HBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_CENTER)
	container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	container.grow_vertical = Control.GROW_DIRECTION_BOTH
	container.add_theme_constant_override("separation", slot_spacing)
	add_child(container)
	
	# Create slots
	for i in range(num_slots):
		var slot := HotbarSlot.new()
		slot.slot_index = i
		if i < hotkeys.size():
			slot.set_hotkey_text(hotkeys[i])
		slots.append(slot)
		container.add_child(slot)


func _connect_signals() -> void:
	for slot in slots:
		slot.slot_pressed.connect(_on_slot_pressed)
		slot.slot_right_clicked.connect(_on_slot_right_clicked)


func _input(event: InputEvent) -> void:
	# Number key shortcuts (1-9)
	if event is InputEventKey and event.pressed and not event.echo:
		var key_str := ""
		match event.keycode:
			KEY_1: key_str = "1"
			KEY_2: key_str = "2"
			KEY_3: key_str = "3"
			KEY_4: key_str = "4"
			KEY_5: key_str = "5"
			KEY_6: key_str = "6"
			KEY_7: key_str = "7"
			KEY_8: key_str = "8"
			KEY_9: key_str = "9"
		
		if key_str != "":
			var idx := hotkeys.find(key_str)
			if idx >= 0 and idx < slots.size():
				_activate_slot(idx)


## Set a skill in a slot
func set_slot_skill(slot_idx: int, skill_id: int, skill_name: String, skill_icon: Texture2D = null) -> void:
	if slot_idx < 0 or slot_idx >= slots.size():
		return
	slots[slot_idx].set_skill(skill_id, skill_name, skill_icon)


## Set an item in a slot
func set_slot_item(slot_idx: int, item_id: int, item_name: String, count: int, item_icon: Texture2D = null) -> void:
	if slot_idx < 0 or slot_idx >= slots.size():
		return
	slots[slot_idx].set_item(item_id, item_name, count, item_icon)


## Update item count in a slot
func update_slot_count(slot_idx: int, count: int) -> void:
	if slot_idx < 0 or slot_idx >= slots.size():
		return
	slots[slot_idx].update_count(count)


## Clear a slot
func clear_slot(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= slots.size():
		return
	slots[slot_idx].clear_slot()


## Start cooldown on a slot
func start_slot_cooldown(slot_idx: int, duration: float) -> void:
	if slot_idx < 0 or slot_idx >= slots.size():
		return
	slots[slot_idx].start_cooldown(duration)


## Find slot containing a skill
func find_skill_slot(skill_id: int) -> int:
	for i in range(slots.size()):
		if slots[i].slot_type == HotbarSlot.SlotType.SKILL and slots[i].content_id == skill_id:
			return i
	return -1


## Find slot containing an item
func find_item_slot(item_id: int) -> int:
	for i in range(slots.size()):
		if slots[i].slot_type == HotbarSlot.SlotType.ITEM and slots[i].content_id == item_id:
			return i
	return -1


func _activate_slot(idx: int) -> void:
	var slot := slots[idx]
	
	if slot.slot_type == HotbarSlot.SlotType.EMPTY:
		return
	
	if slot.is_on_cooldown():
		return
	
	match slot.slot_type:
		HotbarSlot.SlotType.SKILL:
			skill_activated.emit(slot.content_id)
		HotbarSlot.SlotType.ITEM:
			item_used.emit(slot.content_id)


func _on_slot_pressed(slot_idx: int) -> void:
	_activate_slot(slot_idx)


func _on_slot_right_clicked(slot_idx: int) -> void:
	# Right click to clear slot
	clear_slot(slot_idx)
