const { distance } = require('../../../shared/utils/math'); // Fixed require relative pathing

/**
 * Poring AI Script Behavior Module
 * Implements standard PASSIVE behavioral state transitions.
 */
function think(mob, world) {
    const ai = mob.getComponent('ai');
    const move = mob.getComponent('movement');
    const combat = mob.getComponent('combat');
    
    if (!ai || !move || !combat || combat.hp <= 0) {
        return "DEAD";
    }

    const now = Date.now();
    if (now - ai.lastThinkTime < 200) {
        return ai.state;
    }
    ai.lastThinkTime = now;

    switch (ai.state) {
        case "IDLE":
            break;

        case "CHASE": {
            if (!ai.targetId) {
                ai.state = "IDLE";
                break;
            }

            const targetEntity = world.entities.get(ai.targetId);
            if (!targetEntity) {
                ai.targetId = null;
                ai.state = "IDLE";
                break;
            }

            const tMove = targetEntity.getComponent('movement');
            const tCombat = targetEntity.getComponent('combat');
            
            if (!tMove || !tCombat || tCombat.hp <= 0) {
                ai.targetId = null;
                ai.state = "IDLE";
                break;
            }

            const range = distance(move.x, move.y, tMove.x, tMove.y);

            if (range > 10) {
                ai.targetId = null;
                ai.state = "IDLE";
                break;
            }

            if (range > 1.5) {
                move.targetX = tMove.x;
                move.targetY = tMove.y;
                move.isMoving = true;
                move.moveStartTime = now; // CRITICAL FIX: Reset on command issuance to clear tracking ticks
            } else {
                move.isMoving = false;
                ai.state = "ATTACK";
            }
            break;
        }

        case "ATTACK": {
            if (!ai.targetId) {
                ai.state = "IDLE";
                break;
            }

            const targetEntity = world.entities.get(ai.targetId);
            if (!targetEntity) {
                ai.targetId = null;
                ai.state = "IDLE";
                break;
            }

            const tMove = targetEntity.getComponent('movement');
            const tCombat = targetEntity.getComponent('combat');

            if (!tMove || !tCombat || tCombat.hp <= 0) {
                ai.targetId = null;
                ai.state = "IDLE";
                break;
            }

            const range = distance(move.x, move.y, tMove.x, tMove.y);

            if (range > 1.5) {
                ai.state = "CHASE";
            } else {
                const CombatSystem = require('../systems/CombatSystem');
                CombatSystem.attemptAttack(mob, targetEntity, world);
            }
            break;
        }

        default:
            ai.state = "IDLE";
            break;
    }

    return ai.state;
}

module.exports = { think };