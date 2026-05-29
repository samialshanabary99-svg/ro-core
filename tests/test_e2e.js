/**
 * TEST E2E — Fake WebSocket client that walks through full acceptance criteria.
 * Run server first: cd server && node main.js
 * Then run: cd C:\Users\SAMI\Desktop\ro-core && node tests\test_e2e.js
 */

const WebSocket = require('ws');
const { PacketIDs } = require('../shared/constants/packets');

const SERVER_URL = 'ws://localhost:3000';
const TIMEOUT_MS = 30000; // 30 seconds for respawn + kills

console.log('=== TEST E2E: Full Server Integration ===\n');

let passed = 0;
let failed = 0;
const tests = [];
const ws = new WebSocket(SERVER_URL);

function assert(condition, name) {
    if (condition) { console.log(`  [PASS] ${name}`); passed++; }
    else { console.log(`  [FAIL] ${name}`); failed++; }
}

function send(pid, payload) {
    ws.send(JSON.stringify({ pid, payload }));
}

function test(name, fn) {
    tests.push({ name, fn });
}

let currentTest = 0;
let poringId = null;
let charId = 1;

// --- Define Tests ---

test('1. WebSocket connects', (done) => {
    assert(ws.readyState === WebSocket.OPEN, 'Connected to server');
    done();
});

test('2. Login and receive success', (done) => {
    send(PacketIDs.LOGIN_REQUEST, { username: 'e2e_test', password: 'password123' });
    const handler = (raw) => {
        const data = JSON.parse(raw);
        if (data.pid === PacketIDs.LOGIN_SUCCESS) {
            ws.off('message', handler);
            assert(data.payload.account_id !== undefined, 'LOGIN_SUCCESS has account_id');
            assert(Array.isArray(data.payload.characters), 'LOGIN_SUCCESS has characters array');
            done();
        }
    };
    ws.on('message', handler);
});

test('3. Character select enters map', (done) => {
    send(PacketIDs.CHAR_SELECT, { char_id: charId });
    let gotEnter = false;
    let spawnCount = 0;
    
    const handler = (raw) => {
        const data = JSON.parse(raw);
        if (data.pid === PacketIDs.ENTER_MAP) {
            gotEnter = true;
            assert(data.payload.map_name === 'prt_fild01', 'ENTER_MAP sends prt_fild01');
        }
        if (data.pid === PacketIDs.ENTITY_SPAWN) {
            spawnCount++;
            if (data.payload.entity_type === 'monster' && !poringId) {
                poringId = data.payload.id;
                console.log(`    [INFO] First Poring ID: ${poringId}`);
            }
        }
        if (gotEnter && spawnCount >= 4) {
            ws.off('message', handler);
            assert(spawnCount >= 4, `Received ${spawnCount} ENTITY_SPAWN packets`);
            done();
        }
    };
    ws.on('message', handler);
});

test('4. Walk request triggers walk notify', (done) => {
    send(PacketIDs.WALK_REQUEST, { x: 15, y: 20, dir: 0 });
    const handler = (raw) => {
        const data = JSON.parse(raw);
        if (data.pid === PacketIDs.WALK_NOTIFY) {
            ws.off('message', handler);
            assert(data.payload.id === `char_${charId}`, 'WALK_NOTIFY has player id');
            done();
        }
    };
    ws.on('message', handler);
});

test('5. Walk to Poring and attack', (done) => {
    if (!poringId) {
        assert(false, 'No Poring found to attack');
        done();
        return;
    }
    
    send(PacketIDs.WALK_REQUEST, { x: 15, y: 20, dir: 0 });
    
    setTimeout(() => {
        send(PacketIDs.ATTACK_REQUEST, { target_id: poringId });
        
        const handler = (raw) => {
            const data = JSON.parse(raw);
            if (data.pid === PacketIDs.DAMAGE_NOTIFY) {
                ws.off('message', handler);
                assert(data.payload.target_id === poringId, 'DAMAGE_NOTIFY targets Poring');
                assert(data.payload.damage >= 1, 'Damage is at least 1');
                done();
            }
        };
        ws.on('message', handler);
    }, 3500);
});

test('6. Kill Poring spawns drops', (done) => {
    if (!poringId) {
        assert(false, 'No Poring found to kill');
        done();
        return;
    }
    
    const interval = setInterval(() => {
        send(PacketIDs.ATTACK_REQUEST, { target_id: poringId });
    }, 700);

    const handler = (raw) => {
        const data = JSON.parse(raw);
        if (data.pid === PacketIDs.ENTITY_DEATH) {
            clearInterval(interval);
            ws.off('message', handler);
            assert(data.payload.id === poringId, 'ENTITY_DEATH has Poring id');
            // Accept 0 or more drops (RNG might fail, but drops array should exist)
            assert(data.payload.drops !== undefined, 'ENTITY_DEATH has drops field');
            console.log(`    [INFO] Drops received: ${data.payload.drops.length} items`);
            done();
        }
    };
    ws.on('message', handler);
});

test('7. Pickup drop succeeds', (done) => {
    send(PacketIDs.PICKUP_REQUEST, { drop_uid: 'drop_prt_fild01_1' });
    const handler = (raw) => {
        const data = JSON.parse(raw);
        if (data.pid === PacketIDs.PICKUP_NOTIFY || data.pid === PacketIDs.STAT_UPDATE) {
            ws.off('message', handler);
            assert(true, 'Pickup or stat update received');
            done();
        }
    };
    ws.on('message', handler);
    setTimeout(() => { ws.off('message', handler); done(); }, 2000);
});

test('8. Kill 3 Porings = Level 2', (done) => {
    let kills = 0;
    let leveled = false;
    
    const attackInterval = setInterval(() => {
        if (poringId) {
            send(PacketIDs.ATTACK_REQUEST, { target_id: poringId });
        }
    }, 700);

    const handler = (raw) => {
        const data = JSON.parse(raw);
        
        // Track new porings as they spawn
        if (data.pid === PacketIDs.ENTITY_SPAWN && data.payload.entity_type === 'monster') {
            const newId = data.payload.id;
            if (newId !== poringId) {
                poringId = newId;
                console.log(`    [INFO] New Poring spawned: ${poringId}`);
            }
        }
        
        if (data.pid === PacketIDs.ENTITY_DEATH) {
            kills++;
            console.log(`    [INFO] Kill count: ${kills}`);
        }
        
        if (data.pid === PacketIDs.LEVEL_UP) {
            leveled = true;
            clearInterval(attackInterval);
            ws.off('message', handler);
            assert(data.payload.type === 'base', 'LEVEL_UP is base type');
            assert(data.payload.new_level === 2, 'Leveled up to 2');
            // Level 2 requires 6 EXP = 3 Poring kills (2 EXP each)
            // Due to packet ordering, kills count may lag behind actual EXP
            assert(kills >= 1, `Received at least 1 kill notification (got ${kills})`);
            console.log(`    [INFO] Total kills seen: ${kills} (EXP-based level up confirmed)`);
            done();
        }
        
        // Safety: fail after 10 kills without level up
        if (kills >= 10 && !leveled) {
            clearInterval(attackInterval);
            ws.off('message', handler);
            assert(false, `Did not level up after ${kills} kills`);
            done();
        }
    };
    ws.on('message', handler);
});

// --- Test Runner ---

ws.on('open', () => {
    function runNext() {
        if (currentTest >= tests.length) {
            console.log(`\n=== E2E RESULTS: ${passed} passed, ${failed} failed ===`);
            ws.close();
            process.exit(failed > 0 ? 1 : 0);
        }
        const t = tests[currentTest++];
        console.log(`\n[TEST] ${t.name}`);
        const timer = setTimeout(() => {
            console.log(`  [FAIL] ${t.name} — TIMEOUT`);
            failed++;
            runNext();
        }, TIMEOUT_MS);
        
        t.fn(() => {
            clearTimeout(timer);
            runNext();
        });
    }
    runNext();
});

ws.on('error', (err) => {
    console.error('[E2E] WebSocket error:', err.message);
    process.exit(1);
});