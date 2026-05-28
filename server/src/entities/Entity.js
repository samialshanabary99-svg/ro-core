/**
 * Entity
 * Authoritative decoupled container platform. Holds zero logic or domain scripts.
 */
class Entity {
    /**
     * @param {string} id - Explicit uniform unique string UUID identifier
     * @param {string} type - Entities descriptor categories ("player"|"monster"|"drop")
     */
    constructor(id, type) {
        this.id = id;
        this.type = type;
        this.components = new Map();
    }

    /**
     * Attaches a data component instance reference structure safely.
     * @param {string} name 
     * @param {Object} component 
     */
    addComponent(name, component) {
        this.components.set(name, component);
    }

    /**
     * Fetches a standard registered structural data context.
     * @param {string} name 
     * @returns {any}
     */
    getComponent(name) {
        return this.components.get(name);
    }

    /**
     * Validates structural composition footprint.
     * @param {string} name 
     * @returns {boolean}
     */
    hasComponent(name) {
        return this.components.has(name);
    }

    /**
     * Strips data component structure layout allocations cleanly.
     * @param {string} name 
     */
    removeComponent(name) {
        this.components.delete(name);
    }
}

module.exports = Entity;