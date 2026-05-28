const path = require('path');
const config = require('./config.json');

const Database = require('./src/core/MockDatabase');
const Server = require('./src/core/Server');
const GameLoop = require('./src/core/GameLoop');
const DataLoader = require('./src/core/DataLoader');

const MapInstance = require('./src/world/MapInstance');
const SpawnController = require('./src/world/SpawnController');

const MovementSystem = require('./src/systems/MovementSystem');
const DropSystem = require('./src/systems/DropSystem');

const LoginHandler = require('./src/handlers/LoginHandler');
const MovementHandler = require('./src/handlers/MovementHandler');
const CombatHandler = require('./src/handlers/CombatHandler');
const ChatHandler = require('./src/handlers/ChatHandler');

// FIX 7: Lift AI file reading requirements to module load initialization scope
const aiScript = require('./src/scripts/ai_poring');

/**
 * Server Bootstrapping Engine Routine
 */
function bootstrap() {
    console.log('[System] Booting Authoritative MMO Server Environment...');

    // 1. Map Schema Layout Files Parsing Initialization
    const dataLoader = new DataLoader(config);
    dataLoader.init();

    // 2. Establish SQLite Connectivity Parameters
    const db = new Database(config);
    db.init();

    // 3. Bind Event Loop Network Listeners Port Structures
    const server = new Server(config);

    // 4. Instantiate Spatial Zone Layers
    const worldMaps = new Map();
    const spawnControllers = [];

    const prtFild01Template = dataLoader.getMap('prt_fild01');
    if (prtFild01Template) {
        // FIX 8: Confirm 3-parameter layout constructor definitions are supported cleanly
        const mapInst = new MapInstance(prtFild01Template, server, dataLoader);
        worldMaps.set(prtFild01Template.id, mapInst);

        const spawnCtrl = new SpawnController(mapInst, prtFild01Template.spawns, dataLoader);
        spawnCtrl.init();
        spawnControllers.push(spawnCtrl);
    } else {
        console.warn('[System] Warning: Static data properties missing for target workspace: prt_fild01');
    }

    // 5. Connect Active Incoming Request Protocol Parsers
    LoginHandler.register(server, db, dataLoader, worldMaps);
    MovementHandler.register(server);
    CombatHandler.register(server);
    ChatHandler.register(server);

    // 6. Instantiate Continuous Processing Systems Models
    const dropSystem = new DropSystem(server);
    const loop = new GameLoop(config.server.tickRate || 20);

    // 7. Bind Game Loop Timing Sequence Callback Triggers
    loop.onIncomingPackets = () => {};

    loop.onUpdateAI = (dt) => {
        for (const mapInst of worldMaps.values()) {
            for (const entity of mapInst.entities.values()) {
                if (entity.type === 'monster') {
                    aiScript.think(entity, mapInst);
                }
            }
        }
    };

    loop.onUpdateMovement = (dt) => {
        for (const mapInst of worldMaps.values()) {
            MovementSystem.update(mapInst);
        }
    };

    loop.onProcessCombat = (dt) => {};

    loop.onProcessLootAndExp = (dt) => {
        for (const mapInst of worldMaps.values()) {
            const currentController = spawnControllers.find(c => c.mapInstance === mapInst);
            if (currentController) {
                mapInst.processDeaths(dropSystem, currentController);
            }
            dropSystem.updateLifetimes(mapInst);
        }

        for (const ctrl of spawnControllers) {
            ctrl.tick();
        }
    };

    loop.onBroadcastState = () => {};

    // 8. Launch Network Handlers Interfaces
    server.start();
    loop.start();

    process.on('SIGINT', () => {
        console.log('[System] Gracefully interrupting tracking ticks contexts...');
        loop.stop();
        server.shutdown();
        db.close();
        process.exit(0);
    });
}

bootstrap();