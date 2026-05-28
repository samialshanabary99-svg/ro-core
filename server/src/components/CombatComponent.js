/**
 * CombatComponent
 * Dead data structure representing the battle statistics, states, and action cooldowns.
 */
class CombatComponent {
    constructor() {
        // Base Novice Stats (All 1s)
        this.str = 1;
        this.agi = 1;
        this.vit = 1;
        this.int = 1;
        this.dex = 1;
        this.luk = 1;

        // Correct Standalone Base Novice Formula Outputs:
        // Max HP = 40 + (1 * 5) + (1 * 2) = 47
        // Max SP = 11 + (1 * 2) + (1 * 2) = 15
        this.hp = 47;
        this.maxHp = 47;
        this.sp = 15;
        this.maxSp = 15;
        
        // Base ATK = 2 + 1 + floor((1/10)^2) = 3
        this.atkMin = 3;
        this.atkMax = 3;
        this.def = 0;
        
        // Hit = 100 + 1 = 101
        this.hit = 101;
        // Flee = 1 + 1 + 1 = 3
        this.flee = 3;
        // ASPD = floor(156 - 10 * (1 - 1/250)) = floor(146.04) = 146
        this.aspd = 146;
        
        this.lastAttackTime = 0;
        this.statPoints = 0;
        
        this.baseLevel = 1;
        this.jobLevel = 1;
        this.baseExp = 0;
        this.jobExp = 0;
    }
}

module.exports = CombatComponent;