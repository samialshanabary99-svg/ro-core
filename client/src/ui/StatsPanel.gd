## StatsPanel.gd - RO 2004 style character stats window
## Displays HP/SP bars, base stats, and derived stats
extends Control
class_name StatsPanel

## UI references
var panel: Panel
var title_bar: Panel
var title_label: Label
var close_button: Button
var content: VBoxContainer

# HP/SP bars
var hp_bar: ProgressBar
var hp_label: Label
var sp_bar: ProgressBar
var sp_label: Label

# Base stats labels
var str_label: Label
var agi_label: Label
var vit_label: Label
var int_label: Label
var dex_label: Label
var luk_label: Label

# Derived stats labels
var atk_label: Label
var def_label: Label
var matk_label: Label
var mdef_label: Label
var hit_label: Label
var flee_label: Label
var crit_label: Label
var aspd_label: Label

# Character info
var name_label: Label
var job_label: Label
var level_label: Label
var exp_bar: ProgressBar
var exp_label: Label
var job_exp_bar: ProgressBar
var job_exp_label: Label

## Dragging state
var _dragging: bool = false
var _drag_offset: Vector2

## Visibility toggle
var _is_visible: bool = false


func _ready() -> void:
	_setup_ui()
	_connect_signals()
	hide()  # Start hidden


func _setup_ui() -> void:
	# Main panel
	custom_minimum_size = Vector2(280, 420)
	
	panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	style.border_color = Color(0.4, 0.35, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	
	# Title bar
	title_bar = Panel.new()
	title_bar.custom_minimum_size.y = 28
	title_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_bar.offset_bottom = 28
	var title_style := StyleBoxFlat.new()
	title_style.bg_color = Color(0.25, 0.22, 0.2)
	title_style.set_corner_radius_all(4)
	title_style.corner_radius_bottom_left = 0
	title_style.corner_radius_bottom_right = 0
	title_bar.add_theme_stylebox_override("panel", title_style)
	panel.add_child(title_bar)
	
	# Title label
	title_label = Label.new()
	title_label.text = "Status"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_bar.add_child(title_label)
	
	# Close button
	close_button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(24, 24)
	close_button.anchor_left = 1.0
	close_button.anchor_right = 1.0
	close_button.offset_left = -26
	close_button.offset_right = -2
	close_button.offset_top = 2
	close_button.offset_bottom = 26
	title_bar.add_child(close_button)
	
	# Content container
	content = VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_top = 32
	content.offset_left = 8
	content.offset_right = -8
	content.offset_bottom = -8
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)
	
	# Character info section
	_create_character_section()
	
	# HP/SP section
	_create_hp_sp_section()
	
	# Base stats section
	_create_base_stats_section()
	
	# Derived stats section
	_create_derived_stats_section()


func _create_character_section() -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 2)
	content.add_child(section)
	
	name_label = Label.new()
	name_label.text = "Character Name"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	section.add_child(name_label)
	
	var info_row := HBoxContainer.new()
	info_row.alignment = BoxContainer.ALIGNMENT_CENTER
	section.add_child(info_row)
	
	job_label = Label.new()
	job_label.text = "Novice"
	info_row.add_child(job_label)
	
	var sep := Label.new()
	sep.text = " | "
	info_row.add_child(sep)
	
	level_label = Label.new()
	level_label.text = "Base Lv. 1"
	info_row.add_child(level_label)
	
	# Separator
	var hsep := HSeparator.new()
	content.add_child(hsep)


func _create_hp_sp_section() -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	content.add_child(section)
	
	# HP row
	var hp_row := HBoxContainer.new()
	section.add_child(hp_row)
	
	var hp_text := Label.new()
	hp_text.text = "HP"
	hp_text.custom_minimum_size.x = 30
	hp_row.add_child(hp_text)
	
	hp_bar = ProgressBar.new()
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bar.custom_minimum_size.y = 20
	hp_bar.max_value = 100
	hp_bar.value = 100
	hp_bar.show_percentage = false
	var hp_style := StyleBoxFlat.new()
	hp_style.bg_color = Color(0.8, 0.2, 0.2)
	hp_bar.add_theme_stylebox_override("fill", hp_style)
	hp_row.add_child(hp_bar)
	
	hp_label = Label.new()
	hp_label.text = "100/100"
	hp_label.custom_minimum_size.x = 80
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_row.add_child(hp_label)
	
	# SP row
	var sp_row := HBoxContainer.new()
	section.add_child(sp_row)
	
	var sp_text := Label.new()
	sp_text.text = "SP"
	sp_text.custom_minimum_size.x = 30
	sp_row.add_child(sp_text)
	
	sp_bar = ProgressBar.new()
	sp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp_bar.custom_minimum_size.y = 20
	sp_bar.max_value = 100
	sp_bar.value = 100
	sp_bar.show_percentage = false
	var sp_style := StyleBoxFlat.new()
	sp_style.bg_color = Color(0.2, 0.4, 0.8)
	sp_bar.add_theme_stylebox_override("fill", sp_style)
	sp_row.add_child(sp_bar)
	
	sp_label = Label.new()
	sp_label.text = "50/50"
	sp_label.custom_minimum_size.x = 80
	sp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sp_row.add_child(sp_label)
	
	# EXP bars
	exp_bar = _create_exp_row(section, "Exp")
	exp_label = exp_bar.get_parent().get_child(2)
	
	job_exp_bar = _create_exp_row(section, "Job")
	job_exp_label = job_exp_bar.get_parent().get_child(2)
	
	# Separator
	var hsep := HSeparator.new()
	content.add_child(hsep)


func _create_exp_row(parent: Control, label_text: String) -> ProgressBar:
	var row := HBoxContainer.new()
	parent.add_child(row)
	
	var text := Label.new()
	text.text = label_text
	text.custom_minimum_size.x = 30
	row.add_child(text)
	
	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size.y = 16
	bar.max_value = 100
	bar.value = 0
	bar.show_percentage = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.6, 0.6, 0.2)
	bar.add_theme_stylebox_override("fill", style)
	row.add_child(bar)
	
	var label := Label.new()
	label.text = "0%"
	label.custom_minimum_size.x = 80
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(label)
	
	return bar


func _create_base_stats_section() -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 2)
	content.add_child(section)
	
	var header := Label.new()
	header.text = "Base Stats"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
	section.add_child(header)
	
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	section.add_child(grid)
	
	str_label = _create_stat_row(grid, "STR")
	agi_label = _create_stat_row(grid, "AGI")
	vit_label = _create_stat_row(grid, "VIT")
	int_label = _create_stat_row(grid, "INT")
	dex_label = _create_stat_row(grid, "DEX")
	luk_label = _create_stat_row(grid, "LUK")
	
	# Separator
	var hsep := HSeparator.new()
	content.add_child(hsep)


func _create_stat_row(grid: GridContainer, stat_name: String) -> Label:
	var name_lbl := Label.new()
	name_lbl.text = stat_name
	name_lbl.custom_minimum_size.x = 35
	grid.add_child(name_lbl)
	
	var value_lbl := Label.new()
	value_lbl.text = "1"
	value_lbl.custom_minimum_size.x = 30
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(value_lbl)
	
	return value_lbl


func _create_derived_stats_section() -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 2)
	content.add_child(section)
	
	var header := Label.new()
	header.text = "Combat Stats"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
	section.add_child(header)
	
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	section.add_child(grid)
	
	atk_label = _create_stat_row(grid, "ATK")
	def_label = _create_stat_row(grid, "DEF")
	matk_label = _create_stat_row(grid, "MATK")
	mdef_label = _create_stat_row(grid, "MDEF")
	hit_label = _create_stat_row(grid, "HIT")
	flee_label = _create_stat_row(grid, "FLEE")
	crit_label = _create_stat_row(grid, "CRIT")
	aspd_label = _create_stat_row(grid, "ASPD")


func _connect_signals() -> void:
	close_button.pressed.connect(_on_close_pressed)
	title_bar.gui_input.connect(_on_title_bar_input)
	
	# Listen for stat updates from GameState
	if GameState:
		GameState.stats_changed.connect(_on_stats_changed)
		GameState.hp_changed.connect(_on_hp_changed)
		GameState.sp_changed.connect(_on_sp_changed)
		GameState.character_selected.connect(_on_character_selected)


func _input(event: InputEvent) -> void:
	# Toggle with F1
	if event.is_action_pressed("toggle_stats"):
		toggle_visibility()


func _process(_delta: float) -> void:
	if _dragging:
		global_position = get_global_mouse_position() - _drag_offset


## Toggle panel visibility
func toggle_visibility() -> void:
	_is_visible = not _is_visible
	visible = _is_visible


## Update all displayed stats
func update_stats() -> void:
	if not GameState:
		return
	
	# Character info
	name_label.text = GameState.character_name
	job_label.text = _get_job_name(GameState.job_id)
	level_label.text = "Base Lv. %d" % GameState.base_level
	
	# HP/SP
	_on_hp_changed(GameState.current_hp, GameState.max_hp)
	_on_sp_changed(GameState.current_sp, GameState.max_sp)
	
	# EXP
	var exp_percent := 0.0
	if GameState.exp_to_level > 0:
		exp_percent = float(GameState.base_exp) / float(GameState.exp_to_level) * 100.0
	exp_bar.value = exp_percent
	exp_label.text = "%.1f%%" % exp_percent
	
	var job_exp_percent := 0.0
	if GameState.job_exp_to_level > 0:
		job_exp_percent = float(GameState.job_exp) / float(GameState.job_exp_to_level) * 100.0
	job_exp_bar.value = job_exp_percent
	job_exp_label.text = "%.1f%%" % job_exp_percent
	
	# Base stats
	str_label.text = str(GameState.stats.str_stat)
	agi_label.text = str(GameState.stats.agi)
	vit_label.text = str(GameState.stats.vit)
	int_label.text = str(GameState.stats.int_stat)
	dex_label.text = str(GameState.stats.dex)
	luk_label.text = str(GameState.stats.luk)
	
	# Derived stats
	atk_label.text = str(GameState.get_atk())
	def_label.text = str(GameState.get_def())
	matk_label.text = str(GameState.get_matk())
	mdef_label.text = str(GameState.get_mdef())
	hit_label.text = str(GameState.get_hit())
	flee_label.text = str(GameState.get_flee())
	crit_label.text = str(GameState.get_crit())
	aspd_label.text = str(GameState.get_aspd())


func _get_job_name(job_id: int) -> String:
	var job_names := {
		0: "Novice",
		1: "Swordman",
		2: "Mage",
		3: "Archer",
		4: "Acolyte",
		5: "Merchant",
		6: "Thief",
		7: "Knight",
		8: "Priest",
		9: "Wizard",
		10: "Blacksmith",
		11: "Hunter",
		12: "Assassin"
	}
	return job_names.get(job_id, "Unknown")


func _on_close_pressed() -> void:
	_is_visible = false
	hide()


func _on_title_bar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_drag_offset = get_local_mouse_position()
			else:
				_dragging = false


func _on_stats_changed(_stats: Dictionary) -> void:
	update_stats()


func _on_hp_changed(current: int, maximum: int) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current
	hp_label.text = "%d/%d" % [current, maximum]


func _on_sp_changed(current: int, maximum: int) -> void:
	sp_bar.max_value = maximum
	sp_bar.value = current
	sp_label.text = "%d/%d" % [current, maximum]


func _on_character_selected(_char_data: Dictionary) -> void:
	update_stats()
