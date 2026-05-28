/**
 * Core Ragnarok Online mechanics, math formulas, and growth curves.
 */

/**
 * Static Next-Level EXP Requirements (Levels 1 through 10)
 * Lowered floor thresholds to allow 3 Poring kills (3 * 2 EXP = 6 EXP) to trigger level 2.
 * @type {number[]}
 */
const BASE_EXP_TABLE = [0, 6, 18, 40, 80, 180, 400, 800, 1600, 3200, 0];
const JOB_EXP_TABLE  = [0, 3, 10, 20, 40, 90, 200, 400, 800, 1600, 0];

function calculateMaxHP(baseLevel, vit) {
    return 40 + (baseLevel * 5) + (vit * 2);
}

function calculateMaxSP(baseLevel, intel) {
    return 11 + (baseLevel * 2) + (intel * 2);
}

function calculateASPD(weaponDelay, agi) {
    return Math.floor(156 - (weaponDelay * (1 - agi / 250)));
}

function calculateBaseATK(str) {
    return 2 + str + Math.floor(Math.pow(Math.floor(str / 10), 2));
}

function calculateFlee(agi, luk) {
    return 1 + luk + agi;
}

function calculateHitChance(dex, targetFlee) {
    const chance = 100 + dex - targetFlee;
    return Math.max(5, Math.min(100, chance));
}

function calculateCriticalChance(luk) {
    return 1 + Math.floor(luk * 0.3);
}

function calculateAttackInterval(aspd) {
    return 2000 - (aspd * 10);
}

/**
 * Calculates physical damage using exact 2004 specifications.
 * @param {number} atk 
 * @param {number} targetDef 
 * @returns {number}
 */
function calculateDamage(atk, targetDef) {
    const variance = Math.floor(Math.random() * (atk * 0.2 + 1));
    const raw = atk + variance - targetDef;
    return Math.max(1, raw);
}

function getNextBaseExp(level) {
    return BASE_EXP_TABLE[level] ?? 0;
}

function getNextJobExp(level) {
    return JOB_EXP_TABLE[level] ?? 0;
}

module.exports = {
    calculateMaxHP,
    calculateMaxSP,
    calculateASPD,
    calculateBaseATK,
    calculateFlee,
    calculateHitChance,
    calculateCriticalChance,
    calculateAttackInterval,
    calculateDamage,
    getNextBaseExp,
    getNextJobExp,
    UNARMED_DELAY: 10,
    MAX_LEVEL: 10
};