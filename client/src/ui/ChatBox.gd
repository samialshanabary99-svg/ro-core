## ChatBox.gd - RO 2004 style chat window
## Displays messages and handles input for global/party/whisper chat
extends Control
class_name ChatBox

## Chat channels
enum Channel {
	GLOBAL = 0,
	PARTY = 1,
	GUILD = 2,
	WHISPER = 3,
	SYSTEM = 4,
	COMBAT = 5
}

## Channel colors (RO classic style)
const CHANNEL_COLORS := {
	Channel.GLOBAL: Color(1.0, 1.0, 1.0),      # White
	Channel.PARTY: Color(0.5, 1.0, 0.5),       # Light green
	Channel.GUILD: Color(0.5, 0.8, 1.0),       # Light blue
	Channel.WHISPER: Color(1.0, 0.8, 0.5),     # Orange/yellow
	Channel.SYSTEM: Color(1.0, 1.0, 0.5),      # Yellow
	Channel.COMBAT: Color(1.0, 0.5, 0.5),      # Light red
}

## Channel prefixes for display
const CHANNEL_PREFIX := {
	Channel.GLOBAL: "",
	Channel.PARTY: "[Party] ",
	Channel.GUILD: "[Guild] ",
	Channel.WHISPER: "[Whisper] ",
	Channel.SYSTEM: "[System] ",
	Channel.COMBAT: "",
}

## Settings
@export var max_messages: int = 100
@export var fade_time: float = 10.0
@export var show_timestamps: bool = false

## UI references
var chat_container: VBoxContainer
var chat_scroll: ScrollContainer
var input_field: LineEdit
var channel_button: Button
var send_button: Button

## State
var _messages: Array[Dictionary] = []
var _current_channel: Channel = Channel.GLOBAL
var _whisper_target: String = ""
var _is_input_focused: bool = false
var _auto_scroll: bool = true

## Signals
signal message_sent(channel: int, text: String, target: String)


func _ready() -> void:
	_setup_ui()
	_connect_signals()
	
	# Listen for incoming chat from network
	if PacketHandler:
		PacketHandler.chat_received.connect(_on_chat_received)
		PacketHandler.system_message.connect(_on_system_message)


func _setup_ui() -> void:
	# Main container
	custom_minimum_size = Vector2(400, 200)
	anchor_left = 0.0
	anchor_top = 1.0
	anchor_right = 0.0
	anchor_bottom = 1.0
	offset_left = 10
	offset_top = -210
	offset_right = 410
	offset_bottom = -10
	
	# Background panel
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.85)
	style.border_color = Color(0.3, 0.3, 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	bg.add_theme_stylebox_override("panel", style)
	add_child(bg)
	
	# Vertical layout
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	vbox.offset_left = 8
	vbox.offset_top = 8
	vbox.offset_right = -8
	vbox.offset_bottom = -8
	add_child(vbox)
	
	# Scroll container for messages
	chat_scroll = ScrollContainer.new()
	chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chat_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vbox.add_child(chat_scroll)
	
	# Messages container
	chat_container = VBoxContainer.new()
	chat_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_container.add_theme_constant_override("separation", 2)
	chat_scroll.add_child(chat_container)
	
	# Input row
	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 4)
	vbox.add_child(input_row)
	
	# Channel button
	channel_button = Button.new()
	channel_button.text = "All"
	channel_button.custom_minimum_size.x = 60
	channel_button.tooltip_text = "Click to change channel"
	input_row.add_child(channel_button)
	
	# Input field
	input_field = LineEdit.new()
	input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_field.placeholder_text = "Type a message..."
	input_field.max_length = 255
	input_row.add_child(input_field)
	
	# Send button
	send_button = Button.new()
	send_button.text = "Send"
	send_button.custom_minimum_size.x = 60
	input_row.add_child(send_button)


func _connect_signals() -> void:
	channel_button.pressed.connect(_on_channel_button_pressed)
	send_button.pressed.connect(_on_send_pressed)
	input_field.text_submitted.connect(_on_text_submitted)
	input_field.focus_entered.connect(func(): _is_input_focused = true)
	input_field.focus_exited.connect(func(): _is_input_focused = false)
	chat_scroll.get_v_scroll_bar().changed.connect(_on_scroll_changed)


func _input(event: InputEvent) -> void:
	# Press Enter to focus chat
	if event.is_action_pressed("chat_send") and not _is_input_focused:
		input_field.grab_focus()
		get_viewport().set_input_as_handled()
	
	# Escape to unfocus
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _is_input_focused:
			input_field.release_focus()
			get_viewport().set_input_as_handled()


## Add a message to the chat
func add_message(text: String, channel: Channel = Channel.GLOBAL, sender: String = "") -> void:
	var msg := {
		"text": text,
		"channel": channel,
		"sender": sender,
		"time": Time.get_unix_time_from_system()
	}
	_messages.append(msg)
	
	# Trim old messages
	while _messages.size() > max_messages:
		_messages.pop_front()
		if chat_container.get_child_count() > 0:
			chat_container.get_child(0).queue_free()
	
	# Create label for message
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Format message
	var color := CHANNEL_COLORS.get(channel, Color.WHITE)
	var prefix := CHANNEL_PREFIX.get(channel, "")
	var time_str := ""
	
	if show_timestamps:
		var time_dict := Time.get_datetime_dict_from_unix_time(int(msg.time))
		time_str = "[%02d:%02d] " % [time_dict.hour, time_dict.minute]
	
	var formatted := ""
	if sender != "":
		formatted = "%s%s[color=#%s]%s[/color]: %s" % [
			time_str,
			prefix,
			color.to_html(false),
			sender,
			text
		]
	else:
		formatted = "%s%s[color=#%s]%s[/color]" % [
			time_str,
			prefix,
			color.to_html(false),
			text
		]
	
	label.text = formatted
	chat_container.add_child(label)
	
	# Auto-scroll to bottom
	if _auto_scroll:
		await get_tree().process_frame
		chat_scroll.scroll_vertical = int(chat_scroll.get_v_scroll_bar().max_value)


## Add system message
func add_system_message(text: String) -> void:
	add_message(text, Channel.SYSTEM)


## Add combat message
func add_combat_message(text: String) -> void:
	add_message(text, Channel.COMBAT)


## Send the current message
func send_message() -> void:
	var text := input_field.text.strip_edges()
	if text.is_empty():
		return
	
	# Check for whisper command: /w name message or /whisper name message
	if text.begins_with("/w ") or text.begins_with("/whisper "):
		var parts := text.split(" ", false, 2)
		if parts.size() >= 3:
			_whisper_target = parts[1]
			var whisper_text := parts[2]
			message_sent.emit(Channel.WHISPER, whisper_text, _whisper_target)
			add_message("To %s: %s" % [_whisper_target, whisper_text], Channel.WHISPER, GameState.character_name)
		input_field.clear()
		return
	
	# Check for party command
	if text.begins_with("/p ") or text.begins_with("/party "):
		var msg_text := text.substr(text.find(" ") + 1)
		message_sent.emit(Channel.PARTY, msg_text, "")
		input_field.clear()
		return
	
	# Check for guild command
	if text.begins_with("/g ") or text.begins_with("/guild "):
		var msg_text := text.substr(text.find(" ") + 1)
		message_sent.emit(Channel.GUILD, msg_text, "")
		input_field.clear()
		return
	
	# Send on current channel
	message_sent.emit(_current_channel, text, _whisper_target if _current_channel == Channel.WHISPER else "")
	input_field.clear()


## Check if chat input is focused (to block game input)
func is_typing() -> bool:
	return _is_input_focused


## Focus the input field
func focus_input() -> void:
	input_field.grab_focus()


func _on_channel_button_pressed() -> void:
	# Cycle through channels
	var channels := [Channel.GLOBAL, Channel.PARTY, Channel.GUILD]
	var current_idx := channels.find(_current_channel)
	current_idx = (current_idx + 1) % channels.size()
	_current_channel = channels[current_idx]
	
	match _current_channel:
		Channel.GLOBAL:
			channel_button.text = "All"
		Channel.PARTY:
			channel_button.text = "Party"
		Channel.GUILD:
			channel_button.text = "Guild"


func _on_send_pressed() -> void:
	send_message()
	input_field.grab_focus()


func _on_text_submitted(_text: String) -> void:
	send_message()


func _on_scroll_changed() -> void:
	var scrollbar := chat_scroll.get_v_scroll_bar()
	_auto_scroll = scrollbar.value >= scrollbar.max_value - chat_scroll.size.y - 10


func _on_chat_received(sender: String, text: String, channel: int) -> void:
	add_message(text, channel as Channel, sender)


func _on_system_message(text: String) -> void:
	add_system_message(text)
