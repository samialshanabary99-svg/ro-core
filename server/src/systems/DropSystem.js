const DropEntity = require('../entities/DropEntity');
const { PacketIDs } = require('../../../shared/constants/packets');

/**
 * DropSystem
 * Manages item roll distributions, tracking drop lifetimes, and cleanup.
 */
class DropSystem {
    constructor(server) {
        this.server = server;
        this.idCounter = 0;
    }

    processDrops(deadMob, mapInstance, mobTemplateData) {
        if (!mobTemplateData || !mobTemplateData.drops) return;

        const move = deadMob.getComponent('movement');
        if (!move) return;

        const broadcastDrops = [];

        for (const dropConfig of mobTemplateData.drops) {
            const roll = Math.random();
            if (roll <= dropConfig.chance) {
                this.idCounter++;
                const dropUid = `drop_${mapInstance.id}_${this.idCounter}`;
                
                const itemDrop = new DropEntity(dropUid, dropConfig.item_id, 1, move.x, move.y);
                mapInstance.addEntity(itemDrop);

                broadcastDrops.push({
                    item_id: dropConfig.item_id,
                    x: move.x,
                    y: move.y
                });
            }
        }

        mapInstance.server.broadcast(Array.from(mapInstance.sessions.values()), PacketIDs.ENTITY_DEATH, {
            id: deadMob.id,
            drops: broadcastDrops
        });
    }

    updateLifetimes(mapInstance) {
        const now = Date.now();
        for (const entity of mapInstance.entities.values()) {
            if (entity.type === 'drop') {
                if (now - entity.spawnTime >= entity.despawnDurationMs) {
                    mapInstance.removeEntity(entity.id);
                }
            }
        }
    }
}

module.exports = DropSystem;