const Entity = require('./Entity');
const CombatComponent = require('../components/CombatComponent');
const MovementComponent = require('../components/MovementComponent');
const AIComponent = require('../components/AIComponent');

/**
 * Monster Entity Layout Initialization Template Model
 */
class Monster extends Entity {
    constructor(id, mobData) {
        super(id, "monster");
        this.mobId = mobData.id;
        this.name = mobData.name;
        this.sprite = mobData.sprite;

        const movement = new MovementComponent();
        movement.speed = mobData.speed;

        const combat = new CombatComponent();
        combat.hp = mobData.hp;
        combat.maxHp = mobData.hp;
        combat.atkMin = mobData.atk_min;
        combat.atkMax = mobData.atk_max;
        combat.def = mobData.def;
        combat.flee = mobData.flee;
        combat.hit = mobData.hit;
        combat.aspd = mobData.aspd;

        // EXP Pipeline Rewards Cache Definitions
        combat.baseExpReward = mobData.exp_base || 0;
        combat.jobExpReward = mobData.exp_job || 0;
        combat.lastAttackerId = null;

        const ai = new AIComponent();
        ai.aiType = mobData.ai_type;
        ai.state = "IDLE";

        this.addComponent('movement', movement);
        this.addComponent('combat', combat);
        this.addComponent('ai', ai);
    }
}

module.exports = Monster;