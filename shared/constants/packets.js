/**
 * Ragnarok Online 2004 Homage Packet IDs
 * @enum {string}
 */
const PacketIDs = {
    LOGIN_REQUEST:  "0x0064", // Client -> Server
    LOGIN_SUCCESS:  "0x0065", // Server -> Client
    LOGIN_FAIL:     "0x006A", // Server -> Client
    CHAR_SELECT:    "0x006B", // Client -> Server
    ENTER_MAP:      "0x0072", // Server -> Client
    ENTITY_SPAWN:   "0x0078", // Server -> Client
    ENTITY_DESPAWN: "0x0080", // Server -> Client
    WALK_REQUEST:   "0x0085", // Client -> Server
    WALK_NOTIFY:    "0x0086", // Server -> All
    STOP_MOVE:      "0x0087", // Server -> All
    ATTACK_REQUEST: "0x0088", // Client -> Server
    DAMAGE_NOTIFY:  "0x0089", // Server -> All
    ENTITY_DEATH:   "0x0090", // Server -> All
    PICKUP_REQUEST: "0x0091", // Client -> Server
    PICKUP_NOTIFY:  "0x0092", // Server -> Client
    CHAT_MESSAGE:   "0x0093", // Bidirectional
    STAT_UPDATE:    "0x0094", // Server -> Client
    LEVEL_UP:       "0x0095"  // Server -> Client
};

/**
 * Maps packet IDs to descriptive names for debugging and logging.
 * @type {Object<string, string>}
 */
const PacketNames = Object.fromEntries(
    Object.entries(PacketIDs).map(([name, id]) => [id, name])
);

/**
 * Tracks directionality flow for unified pipeline tracking.
 * @enum {string}
 */
const PacketDirection = {
    "0x0064": "C→S", // LoginRequest
    "0x0065": "S→C", // LoginSuccess
    "0x006A": "S→C", // LoginFail
    "0x006B": "C→S", // CharSelect
    "0x0072": "S→C", // EnterMap
    "0x0078": "S→C", // EntitySpawn
    "0x0080": "S→C", // EntityDespawn
    "0x0085": "C→S", // WalkRequest
    "0x0086": "S→C", // WalkNotify
    "0x0087": "S→C", // StopMove
    "0x0088": "C→S", // AttackRequest
    "0x0089": "S→C", // DamageNotify
    "0x0090": "S→C", // EntityDeath
    "0x0091": "C→S", // PickupRequest
    "0x0092": "S→C", // PickupNotify
    "0x0093": "BI",  // ChatMessage (Bidirectional)
    "0x0094": "S→C", // StatUpdate
    "0x0095": "S→C"  // LevelUp
};

module.exports = {
    PacketIDs,
    PacketNames,
    PacketDirection
};