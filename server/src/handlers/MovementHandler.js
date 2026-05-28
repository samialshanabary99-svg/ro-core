const { PacketIDs } = require('../../../shared/constants/packets');

/**
 * MovementHandler
 * Catches user pathing requests and schedules localized navigation logic updates.
 */
class MovementHandler {
    /**
     * @param {Server} server 
     */
    static register(server) {
        
        // Handle Walk Request (0x0085)
        server.registerHandler(PacketIDs.WALK_REQUEST, (session, payload) => {
            const mapInstance = session.activeMap;
            if (!mapInstance || !session.characterId) return;

            const playerEntity = mapInstance.entities.get(`char_${session.characterId}`);
            if (!playerEntity) return;

            const move = playerEntity.getComponent('movement');
            const combat = playerEntity.getComponent('combat');
            
            // Prohibit navigation if deceased
            if (!move || (combat && combat.hp <= 0)) return;

            const { x, y } = payload;

            // Boundary validation check targeting terrain layers
            if (mapInstance.isColliding(x, y)) {
                server.send(session, PacketIDs.STOP_MOVE, {
                    id: playerEntity.id,
                    x: move.x,
                    y: move.y
                });
                return;
            }

            // Assign target vectors to dead component properties
            move.targetX = x;
            move.targetY = y;
            move.isMoving = true;
            move.moveStartTime = Date.now();

            // Calculate lookup orientation index parameters
            const dx = Math.sign(x - move.x);
            const dy = Math.sign(y - move.y);
            if (dx !== 0 || dy !== 0) {
                // Approximate looking direction indices
                move.direction = (dx + 1) + ((dy + 1) * 3);
            }

            // Broadcast movement execution confirmation context parameters out to observers
            mapInstance.server.broadcast(Array.from(mapInstance.sessions.values()), PacketIDs.WALK_NOTIFY, {
                id: playerEntity.id,
                x: move.x,
                y: move.y,
                dir: move.direction
            });
        });
    }
}

module.exports = MovementHandler;