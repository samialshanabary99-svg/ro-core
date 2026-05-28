/**
 * MovementComponent
 * Dead data structure managing spatial positioning, target routing, and tick velocities.
 */
class MovementComponent {
    constructor() {
        this.x = 30;
        this.y = 30;
        this.targetX = 30;
        this.targetY = 30;
        this.speed = 200; // Time in ms to traverse exactly 1 grid tile unit
        this.moveStartTime = 0;
        this.isMoving = false;
        this.direction = 0; // Look direction angle or orthogonal value indices
    }
}

module.exports = MovementComponent;