const { PacketIDs } = require('../../../shared/constants/packets');
const { calculateDamage, calculateHitChance, calculateCriticalChance, calculateAttackInterval } = require('../../../shared/constants/game');
const { rand } = require('../../../shared/utils/math'); // Resolved shared math pathing references

/**
 * CombatSystem
 * Handles hit metrics, damage resolution, and attribution assignments.
 */
class CombatSystem {
    static attemptAttack(attacker, target, mapInstance) {
        const aCombat = attacker.getComponent('combat');
        const tCombat = target.getComponent('combat');
        if (!aCombat || !tCombat || aCombat.hp <= 0 || tCombat.hp <= 0) return;

        const now = Date.now();
        const interval = calculateAttackInterval(aCombat.aspd);
        if (now - aCombat.lastAttackTime < interval) return;

        aCombat.lastAttackTime = now;

        const critRoll = rand(1, 100);
        const critChance = calculateCriticalChance(aCombat.luk);
        const isCrit = critRoll <= critChance;

        let finalDamage = 0;

        if (isCrit) {
            const rawAtk = rand(aCombat.atkMin, aCombat.atkMax);
            finalDamage = Math.max(1, Math.floor(rawAtk + (rawAtk * 0.2))); 
        } else {
            const hitRoll = rand(1, 100);
            const hitChance = calculateHitChance(aCombat.dex, tCombat.flee);

            if (hitRoll > hitChance) {
                mapInstance.server.broadcast(Array.from(mapInstance.sessions.values()), PacketIDs.DAMAGE_NOTIFY, {
                    target_id: target.id,
                    damage: 0,
                    is_crit: false,
                    hp_left: tCombat.hp,
                    attacker_id: attacker.id
                });
                return;
            }

            const baseAtkRoll = rand(aCombat.atkMin, aCombat.atkMax);
            finalDamage = calculateDamage(baseAtkRoll, tCombat.def);
        }

        // Apply health adjustments and assign attribution references for rewards
        tCombat.hp = Math.max(0, tCombat.hp - finalDamage);
        tCombat.lastAttackerId = attacker.id;

        mapInstance.server.broadcast(Array.from(mapInstance.sessions.values()), PacketIDs.DAMAGE_NOTIFY, {
            target_id: target.id,
            damage: finalDamage,
            is_crit: isCrit,
            hp_left: tCombat.hp,
            attacker_id: attacker.id
        });
    }
}

module.exports = CombatSystem;