const { PacketIDs } = require('../../../shared/constants/packets');

/**
 * MapInstance
 * Owns map entity states, spatial tile lookups, and processes active instance pipelines.
 */
class MapInstance {
    constructor(mapData, server, dataLoader) {
        this.id = mapData.id;
        this.width = mapData.width;
        this.height = mapData.height;
        this.server = server;
        this.dataLoader = dataLoader; // Bound to resolve profile properties during data updates

        this.collisionGrid = mapData.collision && mapData.collision.length > 0 
            ? mapData.collision 
            : Array.from({ length: this.height }, () => new Array(this.width).fill(0));

        this.entities = new Map();   
        this.sessions = new Map();   
        
        this.cellSize = 10;
        this.grid = new Map();       
    }

    _getCellKey(x, y) {
        return `${Math.floor(x / this.cellSize)}_${Math.floor(y / this.cellSize)}`;
    }

    addEntity(entity, session = null) {
        this.entities.set(entity.id, entity);
        if (entity.type === 'player' && session) {
            this.sessions.set(entity.id, session);
        }

        const move = entity.getComponent('movement');
        if (move) {
            const key = this._getCellKey(move.x, move.y);
            if (!this.grid.has(key)) this.grid.set(key, new Set());
            this.grid.get(key).add(entity.id);
        }

        const combat = entity.getComponent('combat');
        this.server.broadcast(Array.from(this.sessions.values()), PacketIDs.ENTITY_SPAWN, {
            entity_type: entity.type,
            id: entity.id,
            name: entity.name || 'Unknown',
            sprite: entity.sprite || 'novice',
            x: move ? move.x : 0,
            y: move ? move.y : 0,
            dir: move ? move.direction : 0,
            speed: move ? move.speed : 200,
            hp_percent: combat ? Math.floor((combat.hp / combat.maxHp) * 100) : 100
        });
    }

    removeEntity(entityId) {
        const entity = this.entities.get(entityId);
        if (!entity) return;

        const move = entity.getComponent('movement');
        if (move) {
            const key = this._getCellKey(move.x, move.y);
            if (this.grid.has(key)) {
                this.grid.get(key).delete(entityId);
            }
        }

        this.entities.delete(entityId);
        this.sessions.delete(entityId);

        this.server.broadcast(Array.from(this.sessions.values()), PacketIDs.ENTITY_DESPAWN, {
            id: entityId
        });
    }

    updateSpatialPosition(entityId, oldX, oldY, newX, newY) {
        const oldKey = this._getCellKey(oldX, oldY);
        const newKey = this._getCellKey(newX, newY);

        if (oldKey !== newKey) {
            if (this.grid.has(oldKey)) this.grid.get(oldKey).delete(entityId);
            if (!this.grid.has(newKey)) this.grid.set(newKey, new Set());
            this.grid.get(newKey).add(entityId);
        }
    }

    getNeighbors(x, y, radiusCells = 1) {
        const cx = Math.floor(x / this.cellSize);
        const cy = Math.floor(y / this.cellSize);
        const results = [];

        for (let dx = -radiusCells; dx <= radiusCells; dx++) {
            for (let dy = -radiusCells; dy <= radiusCells; dy++) {
                const cellSet = this.grid.get(`${cx + dx}_${cy + dy}`);
                if (cellSet) {
                    for (const id of cellSet) {
                        const ent = this.entities.get(id);
                        if (ent) results.push(ent);
                    }
                }
            }
        }
        return results;
    }

    isColliding(x, y) {
        if (x < 0 || x >= this.width || y < 0 || y >= this.height) return true;
        return this.collisionGrid[y][x] === 1;
    }

    /**
     * Authoritative Game Loop Hook Execution Pipeline (Step 5)
     */
    processDeaths(dropSystem, spawnController) {
        const ExpSystem = require('../systems/ExpSystem');
        
        for (const [id, entity] of this.entities.entries()) {
            if (entity.type !== 'monster') continue;

            const combat = entity.getComponent('combat');
            if (combat && combat.hp <= 0) {
                // 1. Process experience points and level scaling updates
                ExpSystem.processDeath(entity, this);
                
                // 2. Resolve drops from layout definitions
                const mobData = this.dataLoader.getMonster(entity.mobId);
                if (mobData) {
                    dropSystem.processDrops(entity, this, mobData);
                }
                
                // 3. Register entity to respawn pool configuration parameters
                spawnController.registerDeath(entity);
                
                // 4. Remove entity and broadcast ENTITY_DESPAWN out to observers
                this.removeEntity(id);
            }
        }
    }
}

module.exports = MapInstance;