/**
 * AIComponent
 * Dead data structure maintaining non-player character behavioral automation states.
 */
class AIComponent {
    constructor() {
        /** @type {"IDLE"|"CHASE"|"ATTACK"|"DEAD"} */
        this.state = "IDLE";
        this.targetId = null;
        this.lastThinkTime = 0;
        
        // Home anchor vectors. Overwritten by SpawnController on instantiation.
        this.spawnX = 30;
        this.spawnY = 30;
        this.spawnRadius = 0;
        
        this.aiType = "passive";
    }
}

module.exports = AIComponent;