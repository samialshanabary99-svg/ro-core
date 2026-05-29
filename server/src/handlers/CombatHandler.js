const { PacketIDs } = require('../../../shared/constants/packets');
const CombatSystem = require('../systems/CombatSystem');

/**
 * CombatHandler
 * Handles incoming attack requests.
 */
class CombatHandler {
    static register(server) {
        server.registerHandler(PacketIDs.ATTACK_REQUEST, (session, payload) => {
            const mapInstance = session.activeMap;
            if (!mapInstance || !session.characterId) return;

            const attacker = mapInstance.entities.get(`char_${session.characterId}`);
            const target = mapInstance.entities.get(payload.target_id);

            if (!attacker || !target) return;

            // Route execution request into CombatSystem
            CombatSystem.attemptAttack(attacker, target, mapInstance);
            
            // Aggressively alert AI components to switch threat states
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