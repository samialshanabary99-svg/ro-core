extends Node
class_name NetworkManagerAutoload
## NetworkManager Autoload - WebSocket connection manager for RO Core Client
## Handles connection lifecycle, packet encoding/decoding, and reconnection
## All packets use JSON format: {"pid": "0x00XX", "payload": {...}}

# =============================================================================
# SIGNALS
# =============================================================================

signal connected_to_server()
signal disconnected_from_server()
signal connection_failed(reason: String)
signal packet_received(pid: String, payload: Dictionary)

# =============================================================================
# PACKET IDS - RO 2004 Homage
# =============================================================================

## Client -> Server packets
const PID_LOGIN_REQUEST: String = "0x0064"
const PID_CHAR_SELECT: String = "0x006B"
const PID_WALK_REQUEST: String = "0x0085"
const PID_ATTACK_REQUEST: String = "0x0088"
const PID_PICKUP_REQUEST: String = "0x0091"
const PID_CHAT_MESSAGE: String = "0x0093"

## Server -> Client packets
const PID_LOGIN_SUCCESS: String = "0x0065"
const PID_LOGIN_FAILED: String = "0x0066"
const PID_ENTER_MAP: String = "0x0072"
const PID_ENTITY_SPAWN: String = "0x0078"
const PID_ENTITY_DESPAWN: String = "0x0080"
const PID_WALK_NOTIFY: String = "0x0086"
const PID_STOP_MOVE: String = "0x0087"
const PID_DAMAGE_NOTIFY: String = "0x0089"
const PID_ENTITY_DEATH: String = "0x0090"
const PID_PICKUP_NOTIFY: String = "0x0092"
const PID_STAT_UPDATE: String = "0x0094"
const PID_LEVEL_UP: String = "0x0095"
const PID_SERVER_ERROR: String = "0x00FF"

# =============================================================================
# CONNECTION STATE
# =============================================================================

enum State { DISCONNECTED, CONNECTING, CONNECTED, RECONNECTING }

var _socket: WebSocketPeer = null
var _state: State = State.DISCONNECTED
var _server_url: String = ""
var _reconnect_attempts: int = 0
var _reconnect_timer: float = 0.0

const MAX_RECONNECT_ATTEMPTS: int = 5
const RECONNECT_DELAY_SEC: float = 2.0
const CONNECTION_TIMEOUT_SEC: float = 10.0

var _connection_timer: float = 0.0

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	set_process(false)
	print("[NetworkManager] Autoload initialized")


func _process(delta: float) -> void:
	if _socket == null:
		return
	
	_socket.poll()
	var socket_state: int = _socket.get_ready_state()
	
	match socket_state:
		WebSocketPeer.STATE_CONNECTING:
			_connection_timer += delta
			if _connection_timer >= CONNECTION_TIMEOUT_SEC:
				print("[NetworkManager] Connection timeout")
				_handle_connection_failure("Connection timeout")
		
		WebSocketPeer.STATE_OPEN:
			if _state != State.CONNECTED:
				_state = State.CONNECTED
				_reconnect_attempts = 0
				_connection_timer = 0.0
				connected_to_server.emit()
				print("[NetworkManager] Connected to %s" % _server_url)
			_process_incoming_packets()
		
		WebSocketPeer.STATE_CLOSING:
			pass  # Wait for close
		
		WebSocketPeer.STATE_CLOSED:
			var code: int = _socket.get_close_code()
			var reason: String = _socket.get_close_reason()
			print("[NetworkManager] Socket closed: %d - %s" % [code, reason])
			_handle_disconnect()


func _process_incoming_packets() -> void:
	while _socket.get_available_packet_count() > 0:
		var data: PackedByteArray = _socket.get_packet()
		_decode_and_emit(data)


func _decode_and_emit(data: PackedByteArray) -> void:
	var json_str: String = data.get_string_from_utf8()
	var json: JSON = JSON.new()
	var err: int = json.parse(json_str)
	
	if err != OK:
		push_error("[NetworkManager] JSON parse error: %s" % json.get_error_message())
		return
	
	var packet: Variant = json.data
	if not packet is Dictionary:
		push_error("[NetworkManager] Invalid packet format (not Dictionary)")
		return
	
	var pid: String = packet.get("pid", "")
	var payload: Dictionary = packet.get("payload", {})
	
	if pid.is_empty():
		push_error("[NetworkManager] Packet missing 'pid' field")
		return
	
	print("[NetworkManager] <- %s" % pid)
	packet_received.emit(pid, payload)

# =============================================================================
# CONNECTION METHODS
# =============================================================================

## Connect to game server
func connect_to_server(url: String = "") -> void:
	if url.is_empty():
		url = GameState.DEFAULT_SERVER_URL
	
	if _state == State.CONNECTED:
		print("[NetworkManager] Already connected")
		return
	
	_server_url = url
	_socket = WebSocketPeer.new()
	
	var err: int = _socket.connect_to_url(url)
	if err != OK:
		connection_failed.emit("Failed to initiate connection (error %d)" % err)
		return
	
	_state = State.CONNECTING
	_connection_timer = 0.0
	set_process(true)
	print("[NetworkManager] Connecting to %s..." % url)


## Disconnect from server
func disconnect_from_server() -> void:
	if _socket != null:
		_socket.close(1000, "Client disconnect")
		_socket = null
	
	_state = State.DISCONNECTED
	_reconnect_attempts = 0
	set_process(false)
	GameState.reset()
	disconnected_from_server.emit()
	print("[NetworkManager] Disconnected")


## Check connection status - named to avoid conflict with Object.is_connected()
func is_socket_connected() -> bool:
	return _state == State.CONNECTED


func _handle_connection_failure(reason: String) -> void:
	if _socket != null:
		_socket.close()
		_socket = null
	_state = State.DISCONNECTED
	set_process(false)
	connection_failed.emit(reason)


func _handle_disconnect() -> void:
	_state = State.DISCONNECTED
	set_process(false)
	
	if _reconnect_attempts < MAX_RECONNECT_ATTEMPTS:
		_reconnect_attempts += 1
		print("[NetworkManager] Reconnect attempt %d/%d in %.1fs..." % [
			_reconnect_attempts, MAX_RECONNECT_ATTEMPTS, RECONNECT_DELAY_SEC
		])
		_state = State.RECONNECTING
		await get_tree().create_timer(RECONNECT_DELAY_SEC).timeout
		connect_to_server(_server_url)
	else:
		print("[NetworkManager] Max reconnect attempts reached")
		GameState.reset()
		disconnected_from_server.emit()

# =============================================================================
# PACKET SENDING
# =============================================================================

## Send raw packet with pid and payload
func send_packet(pid: String, payload: Dictionary = {}) -> bool:
	if not is_socket_connected():
		push_warning("[NetworkManager] Cannot send - not connected")
		return false
	
	var packet: Dictionary = {"pid": pid, "payload": payload}
	var json_str: String = JSON.stringify(packet)
	var err: int = _socket.send_text(json_str)
	
	if err != OK:
		push_error("[NetworkManager] Send failed: %s (error %d)" % [pid, err])
		return false
	
	print("[NetworkManager] -> %s" % pid)
	return true

# =============================================================================
# CONVENIENCE PACKET METHODS
# =============================================================================

## 0x0064 - Login Request
func send_login(username: String, password: String) -> void:
	send_packet(PID_LOGIN_REQUEST, {
		"username": username,
		"password": password
	})


## 0x006B - Character Select
func send_char_select(char_id: int) -> void:
	send_packet(PID_CHAR_SELECT, {
		"char_id": char_id
	})


## 0x0085 - Walk Request
func send_walk_request(x: int, y: int, direction: int = 0) -> void:
	send_packet(PID_WALK_REQUEST, {
		"x": x,
		"y": y,
		"dir": direction
	})


## 0x0088 - Attack Request
func send_attack_request(target_id: String) -> void:
	send_packet(PID_ATTACK_REQUEST, {
		"target_id": target_id
	})


## 0x0091 - Pickup Request
func send_pickup_request(drop_uid: String) -> void:
	send_packet(PID_PICKUP_REQUEST, {
		"drop_uid": drop_uid
	})


## 0x0093 - Chat Message
func send_chat(message: String, scope: String = "map") -> void:
	send_packet(PID_CHAT_MESSAGE, {
		"message": message,
		"scope": scope
	})
