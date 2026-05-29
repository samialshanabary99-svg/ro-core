extends Control
class_name LoginScreenScene
## LoginScreen - Handles user authentication and account creation
## Connects to server via NetworkManager, transitions to CharSelect on success

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var username_input: LineEdit = $CenterContainer/LoginPanel/Margin/VBox/UsernameInput
@onready var password_input: LineEdit = $CenterContainer/LoginPanel/Margin/VBox/PasswordInput
@onready var connect_btn: Button = $CenterContainer/LoginPanel/Margin/VBox/ConnectBtn
@onready var status_label: Label = $CenterContainer/LoginPanel/Margin/VBox/StatusLabel
@onready var server_label: Label = $ServerLabel

# =============================================================================
# STATE
# =============================================================================

var _is_busy: bool = false

## Color constants for status messages
const COLOR_INFO: Color = Color(0.6, 0.6, 0.65)
const COLOR_ERROR: Color = Color(0.85, 0.3, 0.3)
const COLOR_SUCCESS: Color = Color(0.3, 0.8, 0.4)

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Display server address
	server_label.text = "Server: %s" % GameState.DEFAULT_SERVER_URL
	
	# Connect UI signals
	connect_btn.pressed.connect(_on_connect_pressed)
	username_input.text_submitted.connect(_on_input_submitted)
	password_input.text_submitted.connect(_on_input_submitted)
	
	# Connect network signals
	NetworkManager.connected_to_server.connect(_on_server_connected)
	NetworkManager.disconnected_from_server.connect(_on_server_disconnected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	
	# Connect packet handler signals
	PacketHandler.login_succeeded.connect(_on_login_success)
	PacketHandler.login_failed.connect(_on_login_failed)
	
	# Focus username field
	username_input.grab_focus()
	_show_status("", COLOR_INFO)
	
	print("[LoginScreen] Ready")

# =============================================================================
# UI CALLBACKS
# =============================================================================

func _on_connect_pressed() -> void:
	_attempt_login()


func _on_input_submitted(_text: String) -> void:
	# Tab from username to password, Enter from password submits
	if username_input.has_focus():
		password_input.grab_focus()
	else:
		_attempt_login()

# =============================================================================
# LOGIN FLOW
# =============================================================================

func _attempt_login() -> void:
	if _is_busy:
		return
	
	# Validate inputs
	var username: String = username_input.text.strip_edges()
	var password: String = password_input.text.strip_edges()
	
	if username.is_empty():
		_show_status("Username required", COLOR_ERROR)
		username_input.grab_focus()
		return
	
	if username.length() < 3:
		_show_status("Username must be at least 3 characters", COLOR_ERROR)
		username_input.grab_focus()
		return
	
	if password.is_empty():
		_show_status("Password required", COLOR_ERROR)
		password_input.grab_focus()
		return
	
	if password.length() < 4:
		_show_status("Password must be at least 4 characters", COLOR_ERROR)
		password_input.grab_focus()
		return
	
	# Start login process
	_set_busy(true)
	_show_status("Connecting...", COLOR_INFO)
	
	if NetworkManager.is_socket_connected():
		# Already connected, send login directly
		_send_login()
	else:
		# Need to connect first
		NetworkManager.connect_to_server()


func _send_login() -> void:
	_show_status("Authenticating...", COLOR_INFO)
	var username: String = username_input.text.strip_edges()
	var password: String = password_input.text.strip_edges()
	NetworkManager.send_login(username, password)

# =============================================================================
# NETWORK CALLBACKS
# =============================================================================

func _on_server_connected() -> void:
	print("[LoginScreen] Server connected, sending login request")
	_send_login()


func _on_server_disconnected() -> void:
	_set_busy(false)
	_show_status("Disconnected from server", COLOR_ERROR)


func _on_connection_failed(reason: String) -> void:
	_set_busy(false)
	_show_status("Connection failed: %s" % reason, COLOR_ERROR)
	print("[LoginScreen] Connection failed: %s" % reason)

# =============================================================================
# PACKET CALLBACKS
# =============================================================================

func _on_login_success(_token: String, char_slots: Array) -> void:
	_show_status("Login successful!", COLOR_SUCCESS)
	print("[LoginScreen] Login success, %d character slots" % char_slots.size())
	
	# Brief delay before transitioning
	await get_tree().create_timer(0.3).timeout
	_go_to_char_select()


func _on_login_failed(reason: String) -> void:
	_set_busy(false)
	_show_status(reason, COLOR_ERROR)
	password_input.clear()
	password_input.grab_focus()
	print("[LoginScreen] Login failed: %s" % reason)

# =============================================================================
# HELPERS
# =============================================================================

func _set_busy(busy: bool) -> void:
	_is_busy = busy
	username_input.editable = not busy
	password_input.editable = not busy
	connect_btn.disabled = busy


func _show_status(message: String, color: Color) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", color)


func _go_to_char_select() -> void:
	# Attempt to load CharSelect scene
	var scene_path: String = "res://src/scenes/CharSelect.tscn"
	
	if ResourceLoader.exists(scene_path):
		var char_select: PackedScene = load(scene_path)
		var instance: Node = char_select.instantiate()
		get_tree().root.add_child(instance)
		queue_free()
	else:
		# CharSelect not yet implemented (Phase 6 complete, waiting for later phases)
		_show_status("Login OK! CharSelect scene pending...", COLOR_SUCCESS)
		_set_busy(false)
		print("[LoginScreen] CharSelect.tscn not found - Phase 6 complete!")
		print("[LoginScreen] Character slots: %s" % str(GameState.char_slots))
