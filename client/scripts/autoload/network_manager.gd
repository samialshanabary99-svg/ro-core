extends Node

signal login_success(data: Dictionary)
signal login_fail(reason: String)
signal enter_map(data: Dictionary)
signal entity_spawn(data: Dictionary)
signal entity_despawn(entity_id: String)
signal walk_notify(data: Dictionary)
signal stop_move(data: Dictionary)
signal damage_notify(data: Dictionary)
signal entity_death(data: Dictionary)
signal pickup_notify(data: Dictionary)
signal chat_message(data: Dictionary)
signal stat_update(data: Dictionary)
signal level_up(data: Dictionary)

var _socket: WebSocketPeer = WebSocketPeer.new()
var _is_connected: bool = false
var _ws_url: String = "ws://127.0.0.1:3000"
var _reconnect_attempts: int = 0
var _max_reconnect_attempts: int = 5
var _reconnect_delay: float = 1.0

func _ready() -> void:
	_load_config()
	_connect_to_server()

func _load_config() -> void:
	if FileAccess.file_exists("res://config/client_config.json"):
		var file = FileAccess.open("res://config/client_config.json", FileAccess.READ)
		var json = JSON.parse_string(file.get_as_text())
		if json and json.has("network"):
			_ws_url = json.network.get("server_url", _ws_url)
			_max_reconnect_attempts = json.network.get("max_reconnect_attempts", _max_reconnect_attempts)
			_reconnect_delay = float(json.network.get("reconnect_delay_ms", 1000)) / 1000.0

func _connect_to_server() -> void:
	print("[Network] Connecting to: ", _ws_url)
	_socket.connect_to_url(_ws_url)

func _process(_delta: float) -> void:
	_socket.poll()
	var state = _socket.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		if not _is_connected:
			print("[Network] Connected.")
			_is_connected = true
			_reconnect_attempts = 0
		
		while _socket.get_available_packet_count() > 0:
			_parse_packet(_socket.get_packet())
			
	elif state == WebSocketPeer.STATE_CLOSED:
		if _is_connected:
			print("[Network] Disconnected.")
			_is_connected = false
			_attempt_reconnect()

func _attempt_reconnect() -> void:
	if _reconnect_attempts < _max_reconnect_attempts:
		_reconnect_attempts += 1
		print("[Network] Reconnect ", _reconnect_attempts, "/", _max_reconnect_attempts, " in ", _reconnect_delay, "s...")
		await get_tree().create_timer(_reconnect_delay).timeout
		_connect_to_server()
	else:
		print("[Network] Max reconnect attempts reached.")

func _parse_packet(bytes: PackedByteArray) -> void:
	var json_str = bytes.get_string_from_utf8()
	var json_data = JSON.parse_string(json_str)
	if not json_data or not json_data.has("pid"):
		return
		
	var packet_id = json_data.pid
	var payload = json_data.get("payload", {})
	
	if FileAccess.file_exists("res://config/client_config.json"):
		var cfg = JSON.parse_string(FileAccess.open("res://config/client_config.json", FileAccess.READ).get_as_text())
		if cfg and cfg.get("debug", {}).get("log_packets", false):
			print("[Network] RX: ", packet_id, " -> ", payload)
	
	match packet_id:
		Packets.LOGIN_SUCCESS: login_success.emit(payload)
		Packets.LOGIN_FAIL: login_fail.emit(payload.get("reason", "Unknown error"))
		Packets.ENTER_MAP: enter_map.emit(payload)
		Packets.ENTITY_SPAWN: entity_spawn.emit(payload)
		Packets.ENTITY_DESPAWN: entity_despawn.emit(payload.get("id", ""))
		Packets.WALK_NOTIFY: walk_notify.emit(payload)
		Packets.STOP_MOVE: stop_move.emit(payload)
		Packets.DAMAGE_NOTIFY: damage_notify.emit(payload)
		Packets.ENTITY_DEATH: entity_death.emit(payload)
		Packets.PICKUP_NOTIFY: pickup_notify.emit(payload)
		Packets.CHAT_MESSAGE: chat_message.emit(payload)
		Packets.STAT_UPDATE: stat_update.emit(payload)
		Packets.LEVEL_UP: level_up.emit(payload)

func _send_packet(packet_id: String, payload: Dictionary) -> void:
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var packet = {"pid": packet_id, "payload": payload}
	var json_bytes = JSON.stringify(packet).to_utf8_buffer()
	_socket.send(json_bytes)

func send_login(user: String, pass_str: String) -> void:
	_send_packet(Packets.LOGIN_REQUEST, {"username": user, "password": pass_str})

func send_char_select(char_id: int) -> void:
	_send_packet(Packets.CHAR_SELECT, {"char_id": char_id})

func send_walk_request(x: int, y: int, dir: int) -> void:
	_send_packet(Packets.WALK_REQUEST, {"x": x, "y": y, "dir": dir})

func send_attack_request(target_id: String) -> void:
	_send_packet(Packets.ATTACK_REQUEST, {"target_id": target_id})

func send_pickup_request(drop_uid: String) -> void:
	_send_packet(Packets.PICKUP_REQUEST, {"drop_uid": drop_uid})

func send_chat_message(scope: String, msg: String) -> void:
	_send_packet(Packets.CHAT_MESSAGE, {"scope": scope, "message": msg})