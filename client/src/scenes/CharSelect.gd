## Phase 10 - Character Selection Screen
## Displayed after successful login, shows character slots

class_name CharacterSelectScreen
extends Control

# UI References
var char_slots: Array[Control] = []
var selected_slot: int = -1
var create_panel: Control
var delete_confirm: Control

# Character data from server
var characters: Array[Dictionary] = []

const MAX_SLOTS := 3
const SLOT_SIZE := Vector2(200, 280)

func _ready() -> void:
	_setup_ui()
	_connect_signals()
	_request_character_list()

func _setup_ui() -> void:
	# Dark background
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.15, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Title
	var title := Label.new()
	title.text = "Select Character"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-100, 40)
	title.size = Vector2(200, 50)
	add_child(title)
	
	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "Ragnarok Online 2004"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	subtitle.position = Vector2(-100, 80)
	subtitle.size = Vector2(200, 30)
	add_child(subtitle)
	
	# Character slots container
	var slots_container := HBoxContainer.new()
	slots_container.set_anchors_preset(Control.PRESET_CENTER)
	slots_container.position = Vector2(-330, -100)
	slots_container.add_theme_constant_override("separation", 30)
	add_child(slots_container)
	
	# Create character slots
	for i in range(MAX_SLOTS):
		var slot := _create_slot(i)
		slots_container.add_child(slot)
		char_slots.append(slot)
	
	# Buttons container
	var btn_container := HBoxContainer.new()
	btn_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	btn_container.position = Vector2(-200, -80)
	btn_container.add_theme_constant_override("separation", 20)
	add_child(btn_container)
	
	# Select button
	var select_btn := Button.new()
	select_btn.text = "Enter Game"
	select_btn.custom_minimum_size = Vector2(120, 40)
	select_btn.pressed.connect(_on_select_pressed)
	btn_container.add_child(select_btn)
	
	# Create button
	var create_btn := Button.new()
	create_btn.text = "Create"
	create_btn.custom_minimum_size = Vector2(100, 40)
	create_btn.pressed.connect(_on_create_pressed)
	btn_container.add_child(create_btn)
	
	# Delete button
	var delete_btn := Button.new()
	delete_btn.text = "Delete"
	delete_btn.custom_minimum_size = Vector2(100, 40)
	delete_btn.pressed.connect(_on_delete_pressed)
	btn_container.add_child(delete_btn)
	
	# Back button
	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(80, 40)
	back_btn.pressed.connect(_on_back_pressed)
	btn_container.add_child(back_btn)
	
	# Create character panel (hidden by default)
	_setup_create_panel()
	
	# Delete confirmation (hidden by default)
	_setup_delete_confirm()

func _create_slot(index: int) -> Control:
	var slot := Panel.new()
	slot.custom_minimum_size = SLOT_SIZE
	slot.name = "Slot_%d" % index
	
	# Slot styling
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 1.0)
	style.border_color = Color(0.3, 0.3, 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	slot.add_theme_stylebox_override("panel", style)
	
	# Character preview area
	var preview := ColorRect.new()
	preview.name = "Preview"
	preview.color = Color(0.12, 0.12, 0.16)
	preview.position = Vector2(10, 10)
	preview.size = Vector2(180, 180)
	slot.add_child(preview)
	
	# Empty slot label
	var empty_label := Label.new()
	empty_label.name = "EmptyLabel"
	empty_label.text = "Empty Slot"
	empty_label.add_theme_font_size_override("font_size", 14)
	empty_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.position = Vector2(10, 10)
	empty_label.size = Vector2(180, 180)
	slot.add_child(empty_label)
	
	# Character name
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = ""
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(10, 200)
	name_label.size = Vector2(180, 25)
	name_label.visible = false
	slot.add_child(name_label)
	
	# Character info (level, job)
	var info_label := Label.new()
	info_label.name = "InfoLabel"
	info_label.text = ""
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.position = Vector2(10, 225)
	info_label.size = Vector2(180, 20)
	info_label.visible = false
	slot.add_child(info_label)
	
	# Map location
	var map_label := Label.new()
	map_label.name = "MapLabel"
	map_label.text = ""
	map_label.add_theme_font_size_override("font_size", 11)
	map_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_label.position = Vector2(10, 248)
	map_label.size = Vector2(180, 20)
	map_label.visible = false
	slot.add_child(map_label)
	
	# Click detection
	slot.gui_input.connect(_on_slot_input.bind(index))
	slot.mouse_entered.connect(_on_slot_hover.bind(index, true))
	slot.mouse_exited.connect(_on_slot_hover.bind(index, false))
	
	return slot

func _setup_create_panel() -> void:
	create_panel = Panel.new()
	create_panel.name = "CreatePanel"
	create_panel.set_anchors_preset(Control.PRESET_CENTER)
	create_panel.position = Vector2(-175, -150)
	create_panel.size = Vector2(350, 300)
	create_panel.visible = false
	add_child(create_panel)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	style.border_color = Color(0.4, 0.4, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	create_panel.add_theme_stylebox_override("panel", style)
	
	# Title
	var title := Label.new()
	title.text = "Create Character"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 20)
	title.size = Vector2(350, 30)
	create_panel.add_child(title)
	
	# Name input
	var name_label := Label.new()
	name_label.text = "Character Name:"
	name_label.position = Vector2(30, 70)
	create_panel.add_child(name_label)
	
	var name_input := LineEdit.new()
	name_input.name = "NameInput"
	name_input.placeholder_text = "Enter name (4-16 chars)"
	name_input.max_length = 16
	name_input.position = Vector2(30, 95)
	name_input.size = Vector2(290, 35)
	create_panel.add_child(name_input)
	
	# Hair style selector
	var hair_label := Label.new()
	hair_label.text = "Hair Style:"
	hair_label.position = Vector2(30, 145)
	create_panel.add_child(hair_label)
	
	var hair_spin := SpinBox.new()
	hair_spin.name = "HairSpin"
	hair_spin.min_value = 0
	hair_spin.max_value = 27
	hair_spin.position = Vector2(30, 170)
	hair_spin.size = Vector2(120, 35)
	create_panel.add_child(hair_spin)
	
	# Hair color selector
	var color_label := Label.new()
	color_label.text = "Hair Color:"
	color_label.position = Vector2(180, 145)
	create_panel.add_child(color_label)
	
	var color_spin := SpinBox.new()
	color_spin.name = "ColorSpin"
	color_spin.min_value = 0
	color_spin.max_value = 8
	color_spin.position = Vector2(180, 170)
	color_spin.size = Vector2(120, 35)
	create_panel.add_child(color_spin)
	
	# Buttons
	var btn_container := HBoxContainer.new()
	btn_container.position = Vector2(70, 240)
	btn_container.add_theme_constant_override("separation", 20)
	create_panel.add_child(btn_container)
	
	var confirm_btn := Button.new()
	confirm_btn.text = "Create"
	confirm_btn.custom_minimum_size = Vector2(90, 35)
	confirm_btn.pressed.connect(_on_create_confirm)
	btn_container.add_child(confirm_btn)
	
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(90, 35)
	cancel_btn.pressed.connect(_on_create_cancel)
	btn_container.add_child(cancel_btn)

func _setup_delete_confirm() -> void:
	delete_confirm = Panel.new()
	delete_confirm.name = "DeleteConfirm"
	delete_confirm.set_anchors_preset(Control.PRESET_CENTER)
	delete_confirm.position = Vector2(-150, -60)
	delete_confirm.size = Vector2(300, 120)
	delete_confirm.visible = false
	add_child(delete_confirm)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.1, 0.1, 0.95)
	style.border_color = Color(0.6, 0.3, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	delete_confirm.add_theme_stylebox_override("panel", style)
	
	var msg := Label.new()
	msg.name = "Message"
	msg.text = "Delete this character?"
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.position = Vector2(0, 25)
	msg.size = Vector2(300, 30)
	delete_confirm.add_child(msg)
	
	var btn_container := HBoxContainer.new()
	btn_container.position = Vector2(60, 65)
	btn_container.add_theme_constant_override("separation", 20)
	delete_confirm.add_child(btn_container)
	
	var yes_btn := Button.new()
	yes_btn.text = "Delete"
	yes_btn.custom_minimum_size = Vector2(80, 30)
	yes_btn.pressed.connect(_on_delete_confirm)
	btn_container.add_child(yes_btn)
	
	var no_btn := Button.new()
	no_btn.text = "Cancel"
	no_btn.custom_minimum_size = Vector2(80, 30)
	no_btn.pressed.connect(_on_delete_cancel)
	btn_container.add_child(no_btn)

func _connect_signals() -> void:
	PacketHandler.char_list_received.connect(_on_char_list_received)
	PacketHandler.char_created.connect(_on_char_created)
	PacketHandler.char_deleted.connect(_on_char_deleted)
	PacketHandler.char_select_result.connect(_on_char_select_result)

func _request_character_list() -> void:
	if NetworkManager.is_socket_connected():
		# Request character list from server
		NetworkManager.send_packet("0x0065", {
			"account_id": GameState.session.get("account_id", 0)
		})
	else:
		# Offline mode - create test character
		_on_char_list_received([
			{
				"char_id": 1,
				"name": "TestChar",
				"job_id": 0,
				"base_level": 1,
				"job_level": 1,
				"map": "prt_fild01",
				"hair_style": 1,
				"hair_color": 0
			}
		])

func _update_slot(index: int, char_data: Dictionary) -> void:
	if index >= char_slots.size():
		return
	
	var slot := char_slots[index]
	var empty_label := slot.get_node("EmptyLabel") as Label
	var name_label := slot.get_node("NameLabel") as Label
	var info_label := slot.get_node("InfoLabel") as Label
	var map_label := slot.get_node("MapLabel") as Label
	var preview := slot.get_node("Preview") as ColorRect
	
	if char_data.is_empty():
		# Empty slot
		empty_label.visible = true
		name_label.visible = false
		info_label.visible = false
		map_label.visible = false
		preview.color = Color(0.12, 0.12, 0.16)
	else:
		# Character exists
		empty_label.visible = false
		name_label.visible = true
		info_label.visible = true
		map_label.visible = true
		
		name_label.text = char_data.get("name", "Unknown")
		
		var job_names := ["Novice", "Swordman", "Mage", "Archer", "Acolyte", "Merchant", "Thief"]
		var job_id: int = char_data.get("job_id", 0)
		var job_name: String = job_names[job_id] if job_id < job_names.size() else "Unknown"
		info_label.text = "Lv.%d %s" % [char_data.get("base_level", 1), job_name]
		
		map_label.text = char_data.get("map", "prt_fild01")
		
		# Job-based preview color
		var job_colors := [
			Color(0.6, 0.5, 0.4),  # Novice - brown
			Color(0.7, 0.3, 0.3),  # Swordman - red
			Color(0.4, 0.4, 0.8),  # Mage - blue
			Color(0.3, 0.7, 0.3),  # Archer - green
			Color(0.8, 0.8, 0.5),  # Acolyte - yellow
			Color(0.7, 0.5, 0.7),  # Merchant - purple
			Color(0.3, 0.3, 0.3),  # Thief - dark
		]
		preview.color = job_colors[job_id] if job_id < job_colors.size() else Color(0.5, 0.5, 0.5)

func _select_slot(index: int) -> void:
	# Deselect previous
	if selected_slot >= 0 and selected_slot < char_slots.size():
		var prev_style := char_slots[selected_slot].get_theme_stylebox("panel") as StyleBoxFlat
		prev_style.border_color = Color(0.3, 0.3, 0.4)
	
	selected_slot = index
	
	# Highlight selected
	if selected_slot >= 0 and selected_slot < char_slots.size():
		var style := char_slots[selected_slot].get_theme_stylebox("panel") as StyleBoxFlat
		style.border_color = Color(0.8, 0.7, 0.4)

# Input handlers
func _on_slot_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_select_slot(index)
			
			# Double click to enter
			if event.double_click and index < characters.size():
				_on_select_pressed()

func _on_slot_hover(index: int, hovering: bool) -> void:
	if index == selected_slot:
		return
	
	var style := char_slots[index].get_theme_stylebox("panel") as StyleBoxFlat
	if hovering:
		style.border_color = Color(0.5, 0.5, 0.6)
	else:
		style.border_color = Color(0.3, 0.3, 0.4)

func _on_select_pressed() -> void:
	if selected_slot < 0 or selected_slot >= characters.size():
		return
	
	var char_data := characters[selected_slot]
	GameState.set_current_character(char_data)
	
	if NetworkManager.is_socket_connected():
		NetworkManager.send_char_select(selected_slot)
	else:
		# Offline mode - go directly to game
		get_tree().change_scene_to_file("res://src/scenes/GameWorld.tscn")

func _on_create_pressed() -> void:
	# Find empty slot
	var empty_slot := -1
	for i in range(MAX_SLOTS):
		if i >= characters.size():
			empty_slot = i
			break
	
	if empty_slot < 0:
		print("[CharSelect] No empty slots available")
		return
	
	create_panel.visible = true
	var name_input := create_panel.get_node("NameInput") as LineEdit
	name_input.text = ""
	name_input.grab_focus()

func _on_delete_pressed() -> void:
	if selected_slot < 0 or selected_slot >= characters.size():
		return
	
	var char_name: String = characters[selected_slot].get("name", "Unknown")
	var msg := delete_confirm.get_node("Message") as Label
	msg.text = "Delete '%s'?" % char_name
	delete_confirm.visible = true

func _on_back_pressed() -> void:
	NetworkManager.disconnect_from_server()
	get_tree().change_scene_to_file("res://src/scenes/LoginScreen.tscn")

func _on_create_confirm() -> void:
	var name_input := create_panel.get_node("NameInput") as LineEdit
	var hair_spin := create_panel.get_node("HairSpin") as SpinBox
	var color_spin := create_panel.get_node("ColorSpin") as SpinBox
	
	var char_name := name_input.text.strip_edges()
	if char_name.length() < 4:
		print("[CharSelect] Name too short")
		return
	
	if NetworkManager.is_socket_connected():
		NetworkManager.send_packet("0x0067", {
			"name": char_name,
			"slot": characters.size(),
			"hair_style": int(hair_spin.value),
			"hair_color": int(color_spin.value),
			"str": 1, "agi": 1, "vit": 1, "int": 1, "dex": 1, "luk": 1
		})
	else:
		# Offline mode
		_on_char_created({
			"char_id": characters.size() + 1,
			"name": char_name,
			"job_id": 0,
			"base_level": 1,
			"job_level": 1,
			"map": "prt_fild01",
			"hair_style": int(hair_spin.value),
			"hair_color": int(color_spin.value)
		})
	
	create_panel.visible = false

func _on_create_cancel() -> void:
	create_panel.visible = false

func _on_delete_confirm() -> void:
	if selected_slot < 0 or selected_slot >= characters.size():
		delete_confirm.visible = false
		return
	
	var char_id: int = characters[selected_slot].get("char_id", 0)
	
	if NetworkManager.is_socket_connected():
		NetworkManager.send_packet("0x0068", {"char_id": char_id})
	else:
		_on_char_deleted(char_id)
	
	delete_confirm.visible = false

func _on_delete_cancel() -> void:
	delete_confirm.visible = false

# Server response handlers
func _on_char_list_received(char_list: Array) -> void:
	characters.clear()
	for char_data in char_list:
		characters.append(char_data)
	
	# Update all slots
	for i in range(MAX_SLOTS):
		if i < characters.size():
			_update_slot(i, characters[i])
		else:
			_update_slot(i, {})
	
	# Auto-select first character if available
	if characters.size() > 0:
		_select_slot(0)

func _on_char_created(char_data: Dictionary) -> void:
	characters.append(char_data)
	_update_slot(characters.size() - 1, char_data)
	_select_slot(characters.size() - 1)

func _on_char_deleted(char_id: int) -> void:
	for i in range(characters.size()):
		if characters[i].get("char_id", -1) == char_id:
			characters.remove_at(i)
			break
	
	# Refresh all slots
	for i in range(MAX_SLOTS):
		if i < characters.size():
			_update_slot(i, characters[i])
		else:
			_update_slot(i, {})
	
	selected_slot = -1
	if characters.size() > 0:
		_select_slot(0)

func _on_char_select_result(success: bool, data: Dictionary) -> void:
	if success:
		get_tree().change_scene_to_file("res://src/scenes/GameWorld.tscn")
	else:
		print("[CharSelect] Character select failed: ", data.get("error", "Unknown error"))
