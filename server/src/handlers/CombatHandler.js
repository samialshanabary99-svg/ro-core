const { PacketIDs } = require('../../../shared/constants/packets');
const CombatSystem = require('../systems/CombatSystem');
const { distance } = require('../../../shared/utils/math');

/**
 * CombatHandler
 * Handles incoming attack requests against valid range validation criteria.
 */
class CombatHandler {
    /**
     * @param {Server} server 
     */
    static register(server) {
        
        // Handle Attack Request (0x0088)
        server.registerHandler(PacketIDs.ATTACK_REQUEST, (session, payload) => {
            const mapInstance = session.activeMap;
            if (!mapInstance || !session.characterId) return;

            const attacker = mapInstance.entities.get(`char_${session.characterId}`);
            const target = mapInstance.entities.get(payload.target_id);

            if (!attacker || !target) return;

            const aMove = attacker.getComponent('movement');
            const tMove = target.getComponent('movement');
            
            if (!aMove || !tMove) return;

            // Enforce basic 1.5 tile grid perimeter range check constraint for melee attacks
            const dst = distance(aMove.x, aMove.y, tMove.x, tMove.y);
            if (dst > 1.5) {
                return; 
            }

            // Route execution request parameters down into systems engine blocks
            CombatSystem.attemptAttack(attacker, target, mapInstance);
            
            // Aggressively alert AI components to switch threat states if attacked entity is an idle monster
            if (target.type === 'monster') {
                const ai = target.getComponent('ai');
                if (ai && ai.state === 'IDLE') {
                    ai.targetId = attacker.id;
                    ai.state = 'CHASE';
                }
            }
        });
    }
}

module.exports = CombatHandler;