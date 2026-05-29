extends Panel

@onready var grid: GridContainer = $GridContainer
@onready var base_lvl_lbl: Label = $BaseLevelLabel
@onready var points_lbl: Label = $PointsLabel

func _ready() -> void:
	NetworkManager.stat_update.connect(_on_stat_update)
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_stat_window"):
		visible = !visible
		GameState.input_mode = "ui" if visible else "game"

func _on_stat_update(data: Dictionary) -> void:
	base_lvl_lbl.text = "Base Level: " + str(data.get("base_level", 1))
	points_lbl.text = "Status Points: " + str(data.get("stat_points", 0))
	
	_update_stat_row("STR", data.get("str", 1))
	_update_stat_row("AGI", data.get("agi", 1))
	_update_stat_row("VIT", data.get("vit", 1))
	_update_stat_row("INT", data.get("int", 1))
	_update_stat_row("DEX", data.get("dex", 1))
	_update_stat_row("LUK", data.get("luk", 1))

func _update_stat_row(stat_name: String, val: int) -> void:
	var val_node = grid.get_node_or_null(stat_name + "Value")
	if val_node and val_node is Label:
		val_node.text = str(val)