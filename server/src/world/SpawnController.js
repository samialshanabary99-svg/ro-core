const Monster = require('../entities/Monster');
const { rand } = require('../../../shared/utils/math'); // Fixed require relative pathing

/**
 * SpawnController
 * Monitors map-configured points and schedules monster respawn updates.
 */
class SpawnController {
    constructor(mapInstance, spawnsConfig, dataLoader) {
        this.mapInstance = mapInstance;
        this.spawnsConfig = spawnsConfig || [];
        this.dataLoader = dataLoader;
        this.deadPool = []; 
        this.idCounter = 0;
    }

    init() {
        for (const spawn of this.spawnsConfig) {
            for (let i = 0; i < spawn.amount; i++) {
                this.spawnMonster(spawn);
            }
        }
    }

    spawnMonster(spawn) {
        const mobData = this.dataLoader.getMonster(spawn.mob_id);
        if (!mobData) return;

        this.idCounter++;
        const uuid = `mob_${this.mapInstance.id}_${this.idCounter}`;
        const monster = new Monster(uuid, mobData);

        const rx = rand(spawn.x - spawn.radius, spawn.x + spawn.radius);
        const ry = rand(spawn.y - spawn.radius, spawn.y + spawn.radius);
        
        const finalX = Math.max(0, Math.min(this.mapInstance.width - 1, rx));
        const finalY = Math.max(0, Math.min(this.mapInstance.height - 1, ry));

        const move = monster.getComponent('movement');
        if (move) {
            move.x = finalX;
            move.y = finalY;
            move.targetX = finalX;
            move.targetY = finalY;
        }

        const ai = monster.getComponent('ai');
        if (ai) {
            ai.spawnX = spawn.x;
            ai.spawnY = spawn.y;
            ai.spawnRadius = spawn.radius;
        }

        monster.spawnConfigRef = spawn; 
        this.mapInstance.addEntity(monster);
    }

    registerDeath(monster) {
        if (!monster.spawnConfigRef) return;
        
        this.deadPool.push({
            spawnConfig: monster.spawnConfigRef,
            respawnTime: Date.now() + (monster.spawnConfigRef.delay || 5000)
        });
    }

    tick() {
        const now = Date.now();
        for (let i = this.deadPool.length - 1; i >= 0; i--) {
            const entry = this.deadPool[i];
            if (now >= entry.respawnTime) {
                this.spawnMonster(entry.spawnConfig);
                this.deadPool.splice(i, 1);
            }
        }
    }
}

module.exports = SpawnController;