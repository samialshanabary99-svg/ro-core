const { PacketIDs } = require('../../../shared/constants/packets');

/**
 * MovementSystem
 * Validates, calculates, and updates continuous linear coordinate path translations.
 */
class MovementSystem {
    static update(mapInstance) {
        const now = Date.now();

        for (const entity of mapInstance.entities.values()) {
            const move = entity.getComponent('movement');
            if (!move || !move.isMoving) continue;

            const elapsed = now - move.moveStartTime;
            const tileProgress = elapsed / move.speed;

            if (tileProgress >= 1) {
                const dx = Math.sign(move.targetX - move.x);
                const dy = Math.sign(move.targetY - move.y);

                const oldX = move.x;
                const oldY = move.y;
                const nextX = move.x + dx;
                const nextY = move.y + dy;

                if (mapInstance.isColliding(nextX, nextY)) {
                    move.isMoving = false;
                    move.targetX = move.x;
                    move.targetY = move.y;
                    
                    mapInstance.server.broadcast(Array.from(mapInstance.sessions.values()), PacketIDs.STOP_MOVE, {
                        id: entity.id,
                        x: move.x,
                        y: move.y
                    });
                    continue;
                }

                move.x = nextX;
                move.y = nextY;
                move.moveStartTime = now;

                mapInstance.updateSpatialPosition(entity.id, oldX, oldY, move.x, move.y);

                mapInstance.server.broadcast(Array.from(mapInstance.sessions.values()), PacketIDs.WALK_NOTIFY, {
                    id: entity.id,
                    x: move.x,
                    y: move.y,
                    dir: move.direction
                });

                if (move.x === move.targetX && move.y === move.targetY) {
                    move.isMoving = false;
                }
            }
        }
    }
}

module.exports = MovementSystem;