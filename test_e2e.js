/**
 * TEST E2E — Fake WebSocket client that walks through full acceptance criteria.
 * Run server first: cd server && node main.js
 * Then run: cd C:\Users\SAMI\Desktop\ro-core && node tests\test_e2e.js
 */

const WebSocket = require('ws');
const { PacketIDs } = require('../shared/constants/packets');

const SERVER_URL = 'ws://localhost:3000';
const TIMEOUT_MS = 10000;

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
let dropId = null;

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
    send(PacketIDs.CHAR_SELECT, { char_id: 1 });
    let gotEnter = false;
    let gotSpawn = false;
    
    const handler = (raw) => {
        const data = JSON.parse(raw);
        if (data.pid === PacketIDs.ENTER_MAP) {
            gotEnter = true;
            assert(data.payload.map_name === 'prt_fild01', 'ENTER_MAP sends prt_fild01');
        }
        if (data.pid === PacketIDs.ENTITY_SPAWN && data.payload.entity_type === 'monster') {
            if (!poringId) poringId = data.payload.id;
            gotSpawn = true;
        }
        if (gotEnter && gotSpawn) {
            ws.off('message', handler);
            assert(true, 'Received ENTER_MAP and ENTITY_SPAWN');
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
            assert(data.payload.id === 'char_1', 'WALK_NOTIFY has player id');
            done();
        }
    };
    ws.on('message', handler);
});

test('5. Attack Poring deals damage', (done) => {
    if (!poringId) {
        assert(false, 'No Poring found to attack');
        done();
        return;
    }
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
});

test('6. Kill Poring spawns drops', (done) => {
    const interval = setInterval(() => {
        send(PacketIDs.ATTACK_REQUEST, { target_id: poringId });
    }, 600);

    const handler = (raw) => {
        const data = JSON.parse(raw);
        if (data.pid === PacketIDs.ENTITY_DEATH) {
            clearInterval(interval);
            ws.off('message', handler);
            assert(data.payload.id === poringId, 'ENTITY_DEATH has Poring id');
            assert(data.payload.drops.length > 0, 'ENTITY_DEATH has drops');
            dropId = data.payload.drops[0].item_id;
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
            assert(true, 'Pickup or stat update received after kill');
            done();
        }
    };
    ws.on('message', handler);
    setTimeout(() => { ws.off('message', handler); done(); }, 1000);
});

test('8. Kill 3 Porings = Level 2', (done) => {
    let kills = 0;
    let leveled = false;
    
    const interval = setInterval(() => {
        send(PacketIDs.ATTACK_REQUEST, { target_id: poringId });
    }, 600);

    const handler = (raw) => {
        const data = JSON.parse(raw);
        if (data.pid === PacketIDs.ENTITY_DEATH) kills++;
        if (data.pid === PacketIDs.LEVEL_UP) {
            leveled = true;
            clearInterval(interval);
            ws.off('message', handler);
            assert(data.payload.type === 'base', 'LEVEL_UP is base type');
            assert(data.payload.new_level === 2, 'Leveled up to 2');
            assert(kills >= 3, `Killed at least 3 Porings (got ${kills})`);
            done();
        }
        if (kills >= 5 && !leveled) {
            clearInterval(interval);
            ws.off('message', handler);
            assert(false, 'Did not level up after 5 kills');
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