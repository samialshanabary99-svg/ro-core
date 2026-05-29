extends Panel

@onready var output_log: RichTextLabel = $RichTextLabel
@onready var input_line: LineEdit = $LineEdit

func _ready() -> void:
	NetworkManager.chat_message.connect(_on_chat_message)
	input_line.focus_exited.connect(_on_chat_blur)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_chat_focus"):
		if not input_line.has_focus():
			input_line.grab_focus()
			GameState.input_mode = "chat"
	elif event.is_action_pressed("ui_accept") and input_line.has_focus():
		_submit_chat()
	elif event.is_action_pressed("ui_cancel") and input_line.has_focus():
		input_line.release_focus()

func _submit_chat() -> void:
	var text: String = input_line.text.strip_edges()
	if not text.is_empty():
		NetworkManager.send_chat_message("say", text)
		input_line.clear()
	input_line.release_focus()

func _on_chat_blur() -> void:
	GameState.input_mode = "game"

func _on_chat_message(data: Dictionary) -> void:
	var msg = data.get("message", "")
	var sender = data.get("sender_id", "Unknown")
	output_log.append_text("[color=yellow]" + sender + ":[/color] " + msg + "\n")