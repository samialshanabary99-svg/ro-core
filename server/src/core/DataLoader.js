const fs = require('fs');
const path = require('path');
const yaml = require('yaml');

/**
 * DataLoader
 * Synchronously caches global schema configuration maps directly out of key-value root configurations.
 */
class DataLoader {
    constructor(config) {
        this.config = config;
        this.jobs = new Map();
        this.monsters = new Map();
        this.maps = new Map();
    }

    init() {
        try {
            // 1. Process Job Layout Dictionary Configurations
            const jobsRaw = fs.readFileSync(path.resolve(this.config.data.jobsPath), 'utf8');
            const jobsParsed = yaml.parse(jobsRaw);
            if (jobsParsed) {
                Object.values(jobsParsed).forEach(job => this.jobs.set(job.id, job));
            }

            // 2. Process Monster Layout Dictionary Configurations
            const monstersRaw = fs.readFileSync(path.resolve(this.config.data.monstersPath), 'utf8');
            const monstersParsed = yaml.parse(monstersRaw);
            if (monstersParsed) {
                Object.values(monstersParsed).forEach(mob => this.monsters.set(mob.id, mob));
            }

            // 3. Process Map Layout Dictionary Configurations
            const mapsRaw = fs.readFileSync(path.resolve(this.config.data.mapsPath), 'utf8');
            const mapsParsed = yaml.parse(mapsRaw);
            if (mapsParsed) {
                Object.values(mapsParsed).forEach(mapObj => this.maps.set(mapObj.id, mapObj));
            }

            console.log(`[DataLoader] Assets Cached: ${this.jobs.size} Jobs, ${this.monsters.size} Mobs, ${this.maps.size} Maps.`);
        } catch (error) {
            console.error('[DataLoader] Failed to cache static definitions:', error.message);
            throw error;
        }
    }

    getJob(id) { return this.jobs.get(id); }
    getMonster(id) { return this.monsters.get(id); }
    getMap(id) { return this.maps.get(id); }
}

module.exports = DataLoader;