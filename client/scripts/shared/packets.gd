class_name Packets
extends RefCounted

# Client → Server
const LOGIN_REQUEST: String  = "0x0064"
const CHAR_SELECT: String    = "0x006B"
const WALK_REQUEST: String   = "0x0085"
const ATTACK_REQUEST: String = "0x0088"
const PICKUP_REQUEST: String = "0x0091"
const CHAT_MESSAGE: String   = "0x0093"

# Server → Client
const LOGIN_SUCCESS: String  = "0x0065"
const LOGIN_FAIL: String     = "0x006A"
const ENTER_MAP: String      = "0x0072"
const ENTITY_SPAWN: String   = "0x0078"
const ENTITY_DESPAWN: String = "0x0080"
const WALK_NOTIFY: String    = "0x0086"
const STOP_MOVE: String      = "0x0087"
const DAMAGE_NOTIFY: String  = "0x0089"
const ENTITY_DEATH: String   = "0x0090"
const PICKUP_NOTIFY: String  = "0x0092"
const STAT_UPDATE: String    = "0x0094"
const LEVEL_UP: String       = "0x0095"