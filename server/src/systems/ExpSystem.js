const { PacketIDs } = require('../../../shared/constants/packets');
const { getNextBaseExp, getNextJobExp, calculateMaxHP, calculateMaxSP } = require('../../../shared/constants/game');

/**
 * ExpSystem
 * Tracks experience accumulation, character leveling updates, and stat scaling properties.
 */
class ExpSystem {
    /**
     * Resolves individual rewards processing curves.
     * @param {Entity} deadMob 
     * @param {MapInstance} mapInstance 
     */
    static processDeath(deadMob, mapInstance) {
        const mCombat = deadMob.getComponent('combat');
        if (!mCombat || !mCombat.lastAttackerId) return;

        const attacker = mapInstance.entities.get(mCombat.lastAttackerId);
        if (!attacker || attacker.type !== 'player') return;

        const aCombat = attacker.getComponent('combat');
        const session = mapInstance.sessions.get(attacker.id);
        if (!aCombat || !session) return;

        // Accumulate experience points values
        aCombat.baseExp += mCombat.baseExpReward || 0;
        aCombat.jobExp += mCombat.jobExpReward || 0;

        let baseLeveled = false;
        let jobLeveled = false;

        // 1. Process Base Leveling Curve Loops
        let nextBase = getNextBaseExp(aCombat.baseLevel);
        while (nextBase > 0 && aCombat.baseExp >= nextBase) {
            aCombat.baseExp -= nextBase;
            aCombat.baseLevel++;
            aCombat.statPoints++;
            baseLeveled = true;
            nextBase = getNextBaseExp(aCombat.baseLevel);
        }

        // 2. Process Job Leveling Curve Loops
        let nextJob = getNextJobExp(aCombat.jobLevel);
        while (nextJob > 0 && aCombat.jobExp >= nextJob) {
            aCombat.jobExp -= nextJob;
            aCombat.jobLevel++;
            jobLeveled = true;
            nextJob = getNextJobExp(aCombat.jobLevel);
        }

        // 3. Recalculate status modifications and apply structural resource regeneration updates
        if (baseLeveled) {
            aCombat.maxHp = calculateMaxHP(aCombat.baseLevel, aCombat.vit);
            aCombat.maxSp = calculateMaxSP(aCombat.baseLevel, aCombat.int);
            aCombat.hp = aCombat.maxHp;
            aCombat.sp = aCombat.maxSp;
        }

        // 4. Dispatch status alerts out to target connection sessions
        if (baseLeveled) {
            mapInstance.server.send(session, PacketIDs.LEVEL_UP, { type: 'base', new_level: aCombat.baseLevel });
        }
        if (jobLeveled) {
            mapInstance.server.send(session, PacketIDs.LEVEL_UP, { type: 'job', new_level: aCombat.jobLevel });
        }

        // Always push status parameters to re-align tracking interface components
        mapInstance.server.send(session, PacketIDs.STAT_UPDATE, {
            str: aCombat.str, agi: aCombat.agi, vit: aCombat.vit,
            int: aCombat.int, dex: aCombat.dex, luk: aCombat.luk,
            hp: aCombat.hp, max_hp: aCombat.maxHp,
            sp: aCombat.sp, max_sp: aCombat.maxSp,
            base_exp: aCombat.baseExp, next_base_exp: getNextBaseExp(aCombat.baseLevel),
            job_exp: aCombat.jobExp, next_job_exp: getNextJobExp(aCombat.jobLevel),
            stat_points: aCombat.statPoints
        });
    }
}

module.exports = ExpSystem;