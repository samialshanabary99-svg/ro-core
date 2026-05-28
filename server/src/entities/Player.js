const Entity = require('./Entity');
const CombatComponent = require('../components/CombatComponent');
const MovementComponent = require('../components/MovementComponent');
const { calculateMaxHP, calculateMaxSP, calculateBaseATK, calculateASPD, calculateFlee, UNARMED_DELAY } = require('../../../shared/constants/game');

/**
 * Player Entity Configuration Factory Wrapper
 */
class Player extends Entity {
    /**
     * @param {string} id - Matches active Session Character Database ID 
     * @param {string} name 
     * @param {Object} jobData - Novice schema parameters passed from central DataLoader cache
     */
    constructor(id, name, jobData) {
        super(id, "player");
        this.name = name;
        this.jobId = jobData.id;

        const movement = new MovementComponent();
        const combat = new CombatComponent();

        this.addComponent('movement', movement);
        this.addComponent('combat', combat);
        
        // Re-run dynamic stat mapping definitions using the primary formula definitions
        this.refreshStats();
    }

    /**
     * Synchronizes dynamic composite attributes from raw base stat configurations.
     * Clamps current Vitals safely to their new max allocations.
     */
    refreshStats() {
        const combat = this.getComponent('combat');
        if (!combat) return;

        combat.maxHp = calculateMaxHP(combat.baseLevel, combat.vit);
        combat.maxSp = calculateMaxSP(combat.baseLevel, combat.int);
        
        const baseAtk = calculateBaseATK(combat.str);
        combat.atkMin = baseAtk;
        combat.atkMax = Math.floor(baseAtk + (baseAtk * 0.2));
        
        combat.def = Math.floor(combat.vit / 2); 
        combat.aspd = calculateASPD(UNARMED_DELAY, combat.agi);
        combat.flee = calculateFlee(combat.agi, combat.luk);
        combat.hit = 100 + combat.dex;

        // Lifecycle ceiling verification clamps
        combat.hp = Math.min(combat.hp, combat.maxHp);
        combat.sp = Math.min(combat.sp, combat.maxSp);
    }
}

module.exports = Player;