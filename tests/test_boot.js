/**
 * TEST BOOT — Validates all modules load, YAML parses, and formulas are correct.
 * Run: cd C:\Users\SAMI\Desktop\ro-core && node tests\test_boot.js
 */

const path = require('path');

console.log('=== TEST BOOT: Module Loading ===\n');

let passed = 0;
let failed = 0;

function assert(condition, name) {
    if (condition) {
        console.log(`  [PASS] ${name}`);
        passed++;
    } else {
        console.log(`  [FAIL] ${name}`);
        failed++;
    }
}

// --- Test 1: Shared Constants ---
try {
    const { PacketIDs, PacketNames, PacketDirection } = require('../shared/constants/packets');
    assert(Object.keys(PacketIDs).length >= 17, 'PacketIDs has all packet constants');
    assert(PacketNames['0x0064'] === 'LOGIN_REQUEST', 'PacketNames reverse lookup works');
    assert(PacketDirection['0x0064'] === 'C→S', 'PacketDirection has LOGIN_REQUEST');
    assert(PacketDirection['0x0093'] === 'BI', 'PacketDirection marks Chat as Bidirectional');
    assert(PacketNames['0x006A'] === 'LOGIN_FAIL', 'PacketNames has LOGIN_FAIL');
} catch (e) {
    console.error('[CRASH] packets.js:', e.message);
    failed += 5;
}

// --- Test 2: Game Formulas ---
try {
    const Game = require('../shared/constants/game');
    assert(Game.calculateMaxHP(1, 1) === 47, 'Lv1 VIT1 HP = 47');
    assert(Game.calculateMaxSP(1, 1) === 15, 'Lv1 INT1 SP = 15');
    assert(Game.calculateBaseATK(1) === 3, 'STR1 ATK = 3');
    assert(Game.calculateASPD(10, 1) === 146, 'Unarmed AGI1 ASPD = 146');
    assert(Game.calculateAttackInterval(146) === 540, 'ASPD146 interval = 540ms');
    assert(Game.getNextBaseExp(1) === 6, 'Base Lv1→2 needs 6 EXP');
    assert(Game.getNextJobExp(1) === 3, 'Job Lv1→2 needs 3 EXP');
    assert(Game.getNextBaseExp(10) === 0, 'Max base level has 0 next EXP');
} catch (e) {
    console.error('[CRASH] game.js:', e.message);
    failed += 8;
}

// --- Test 3: YAML Data Loading ---
try {
    const fs = require('fs');
    const yaml = require('yaml');
    
    const jobsRaw = fs.readFileSync(path.join(__dirname, '../shared/data/jobs.yml'), 'utf8');
    const jobs = yaml.parse(jobsRaw);
    assert(jobs.novice.id === 0, 'jobs.yml: Novice id = 0');
    assert(jobs.novice.max_base_level === 10, 'jobs.yml: Novice max base level = 10');
    
    const mobsRaw = fs.readFileSync(path.join(__dirname, '../shared/data/monsters.yml'), 'utf8');
    const mobs = yaml.parse(mobsRaw);
    assert(mobs.poring.id === 1002, 'monsters.yml: Poring id = 1002');
    assert(mobs.poring.hp === 50, 'monsters.yml: Poring HP = 50');
    assert(mobs.poring.drops.length === 2, 'monsters.yml: Poring has 2 drops');
    
    const mapsRaw = fs.readFileSync(path.join(__dirname, '../shared/data/maps.yml'), 'utf8');
    const maps = yaml.parse(mapsRaw);
    assert(maps.prt_fild01.width === 60, 'maps.yml: prt_fild01 width = 60');
    assert(maps.prt_fild01.spawns.length === 3, 'maps.yml: prt_fild01 has 3 spawns');
} catch (e) {
    console.error('[CRASH] YAML parsing:', e.message);
    failed += 6;
}

// --- Test 4: Math Utils ---
try {
    const MathUtil = require('../shared/utils/math');
    assert(MathUtil.clamp(5, 0, 10) === 5, 'clamp middle');
    assert(MathUtil.clamp(-5, 0, 10) === 0, 'clamp min');
    assert(MathUtil.clamp(15, 0, 10) === 10, 'clamp max');
    const r = MathUtil.rand(1, 3);
    assert(r >= 1 && r <= 3, 'rand range');
    assert(MathUtil.distance(0, 0, 3, 4) === 5, 'distance 3-4-5');
    assert(MathUtil.manhattanDistance(0, 0, 3, 4) === 7, 'manhattan = 7');
    assert(MathUtil.lerp(0, 10, 0.5) === 5, 'lerp half');
} catch (e) {
    console.error('[CRASH] math.js:', e.message);
    failed += 7;
}

// --- Test 5: Server Core Modules (with Mock DB) ---
try {
    const PacketFactory = require('../server/src/core/PacketFactory');
    const encoded = PacketFactory.encode('0x0064', { username: 'test' });
    const decoded = PacketFactory.decode(encoded);
    assert(decoded.pid === '0x0064', 'PacketFactory round-trip');
    assert(decoded.payload.username === 'test', 'PacketFactory payload intact');
    
    const bad = PacketFactory.decode('{"bad":"json');
    assert(bad === null, 'PacketFactory rejects malformed JSON');
    
    const GameLoop = require('../server/src/core/GameLoop');
    const loop = new GameLoop(20);
    assert(loop.tickRateMs === 50, 'GameLoop 20Hz = 50ms');
    
    const Server = require('../server/src/core/Server');
    const MockDatabase = require('../server/src/core/MockDatabase');
    const db = new MockDatabase();
    db.init();
    assert(db.statements.createAccount.run('test', 'hash', 0).lastInsertRowid === 1, 'MockDB creates account');
    const acc = db.statements.getAccountByUsername.get('test');
    assert(acc && acc.username === 'test', 'MockDB retrieves account');
    db.close();
} catch (e) {
    console.error('[CRASH] Server core:', e.message);
    console.error(e.stack);
    failed += 5;
}

// --- Summary ---
console.log(`\n=== BOOT RESULTS: ${passed} passed, ${failed} failed ===`);
process.exit(failed > 0 ? 1 : 0);