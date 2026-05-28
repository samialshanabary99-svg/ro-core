/**
 * Shared utility arithmetic operations for layout processing, collision mechanics,
 * and vector verification.
 */

/**
 * Restricts a value between a minimum and maximum boundaries.
 * @param {number} value 
 * @param {number} min 
 * @param {number} max 
 * @returns {number}
 */
function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
}

/**
 * Generates a random integer between min and max parameters (inclusive).
 * @param {number} min 
 * @param {number} max 
 * @returns {number}
 */
function rand(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
}

/**
 * Calculates standard Euclidean distance between two coordinate entities.
 * Used for range verification checks inside Combat and AI controllers.
 * @param {number} x1 
 * @param {number} y1 
 * @param {number} x2 
 * @param {number} y2 
 * @returns {number}
 */
function distance(x1, y1, x2, y2) {
    return Math.sqrt(Math.pow(x2 - x1, 2) + Math.pow(y2 - y1, 2));
}

/**
 * Calculates standard Manhattan distance between two tile grid positions.
 * Ideal for rapid orthogonal movement calculations.
 * @param {number} x1 
 * @param {number} y1 
 * @param {number} x2 
 * @param {number} y2 
 * @returns {number}
 */
function manhattanDistance(x1, y1, x2, y2) {
    return Math.abs(x2 - x1) + Math.abs(y2 - y1);
}

/**
 * Performs linear interpolation between two values.
 * @param {number} start 
 * @param {number} end 
 * @param {number} alpha 
 * @returns {number}
 */
function lerp(start, end, alpha) {
    return start + (end - start) * clamp(alpha, 0, 1);
}

module.exports = {
    clamp,
    rand,
    distance,
    manhattanDistance,
    lerp
};