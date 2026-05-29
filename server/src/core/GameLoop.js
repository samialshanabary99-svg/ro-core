/**
 * Deterministic Server Heartbeat Controller.
 * Manages game systems execution sequence inside isolated single-threaded intervals.
 */
class GameLoop {
    /**
     * @param {number} tickRateHz - Core frequency rate target (20Hz = 50ms intervals)
     */
    constructor(tickRateHz = 20) {
        this.tickRateMs = 1000 / tickRateHz;
        this.timerId = null;
        this.isRunning = false;
        this.lastTickTime = 0;

        // Delegated execution hooks bound from world engine architectures
        this.onIncomingPackets = null;
        this.onUpdateAI = null;
        this.onUpdateMovement = null;
        this.onProcessCombat = null;
        this.onProcessLootAndExp = null;
        this.onBroadcastState = null;
    }

    /**
     * Starts game loop runtime loops.
     */
    start() {
        if (this.isRunning) return;
        this.isRunning = true;
        this.lastTickTime = Date.now();
        
        // Target fixed updates processing step frames safely
        this.timerId = setInterval(() => this.tick(), this.tickRateMs);
        console.log(`[GameLoop] Loop running continuously at a targeted resolution of ${this.tickRateMs}ms.`);
    }

    /**
     * Unified execution logic order block framing sequences.
     */
    tick() {
        const now = Date.now();
        let deltaTime = (now - this.lastTickTime) / 1000;
        this.lastTickTime = now;

        // Frame cap threshold restriction to preserve calculations if scheduling slips
        if (deltaTime > 0.25) {
            deltaTime = 0.25;
        }

        try {
            // Sequence Pipeline Matrix (1 through 6)
            if (this.onIncomingPackets)   this.onIncomingPackets();
            if (this.onUpdateAI)          this.onUpdateAI(deltaTime);
            if (this.onUpdateMovement)    this.onUpdateMovement(deltaTime);
            if (this.onProcessCombat)     this.onProcessCombat(deltaTime);
            if (this.onProcessLootAndExp) this.onProcessLootAndExp(deltaTime);
            if (this.onBroadcastState)    this.onBroadcastState();
            
        } catch (error) {
            console.error('[GameLoop] Processing Pipeline crashed inside iteration block:', error.stack);
        }
    }

    /**
     * Suspends active loop executions instantly.
     */
    stop() {
        if (!this.isRunning) return;
        clearInterval(this.timerId);
        this.timerId = null;
        this.isRunning = false;
        console.log('[GameLoop] Heartbeat processing execution loop stopped.');
    }
}

module.exports = GameLoop;