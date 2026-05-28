const Entity = require('./Entity');
const MovementComponent = require('../components/MovementComponent');

/**
 * DropEntity
 * In-world container item ground allocations available for pickup tracking.
 */
class DropEntity extends Entity {
    /**
     * @param {string} id - Map runtime global drop transaction tracker uid 
     * @param {number} itemId - Global database reference tracking identification number
     * @param {number} amount - Item quantity stack allocation sizes
     * @param {number} x - Target terrain tile X layout coordinate drop location
     * @param {number} y - Target terrain tile Y layout coordinate drop location
     */
    constructor(id, itemId, amount, x, y) {
        super(id, "drop");
        this.itemId = itemId;
        this.amount = amount;
        this.spawnTime = Date.now();
        this.despawnDurationMs = 30000; // Explicit 30-second world persistent lifespan window

        const movement = new MovementComponent();
        movement.x = x;
        movement.y = y;
        movement.targetX = x;
        movement.targetY = y;
        movement.isMoving = false;

        this.addComponent('movement', movement);
    }

    /**
     * Evaluates expiration constraints during world system evaluation steps.
     * @returns {boolean} True if entity should be aggressively stripped and removed from loop tracking
     */
    isExpired() {
        return (Date.now() - this.spawnTime) >= this.despawnDurationMs;
    }
}

module.exports = DropEntity;