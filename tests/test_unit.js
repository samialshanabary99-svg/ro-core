/**
 * TEST UNIT — Tests entities, components, and systems in isolation.
 * Run: cd C:\Users\SAMI\Desktop\ro-core && node tests\test_unit.js
 */

const path = require('path');

const { PacketIDs } = require('../shared/constants/packets');
const Game = require('../shared/constants/game');
const MathUtil = require('../shared/utils/math');

const Entity = require('../server/src/entities/Entity');
const Player = require('../server/src/entities/Player');
const Monster = require('../server/src/entities/Monster');
const DropEntity = require('../server/src/entities/DropEntity');

const CombatSystem = require('../server/src/systems/CombatSystem');
const DropSystem = require('../server/src/systems/DropSystem');

const MockDatabase = require('../server/src/core/MockDatabase');
const DataLoader = require('../server/src/core/DataLoader');
const MapInstance = require('../server/src/world/MapInstance');
const SpawnController = require('../server/src/world/SpawnController');

console.log('=== TEST UNIT: Components & Systems ===\n');

let passed = 0;
let failed = 0;

function assert(condition, name) {
    if (condition) { console.log(`  [PASS] ${name}`); passed++; }
    else { console.log(`  [FAIL] ${name}`); failed++; }
}

// --- Test Player Entity ---
const jobTemplate = {
    id: 0, name: 'Novice', max_base_level: 10, max_job_level: 10,
    base_hp: 40, base_sp: 11, hp_factor: 5, sp_factor: 2,
    stat_bonus: { str: 0, agi: 0, vit: 0, int: 0, dex: 0, luk: 0 },
    skill_tree: []
};

const player = new Player('char_1', 'TestNovice', jobTemplate);
const pCombat = player.getComponent('combat');
const pMove = player.getComponent('movement');

assert(pCombat.hp === 47, 'Player spawns with 47 HP');
assert(pCombat.maxHp === 47, 'Player max HP = 47');
assert(pCombat.sp === 15, 'Player spawns with 15 SP');
assert(pCombat.atkMin === 3, 'Player ATK min = 3 (STR1)');
assert(pCombat.aspd === 146, 'Player ASPD = 146');
assert(pMove.x === 30 && pMove.y === 30, 'Player spawns at 30,30');

// --- Test Monster Entity ---
const mobTemplate = {
    id: 1002, name: 'Poring', sprite: 'poring', hp: 50,
    atk_min: 1, atk_max: 2, def: 0, flee: 1, hit: 5, aspd: 40,
    speed: 200, ai_type: 'passive', exp_base: 2, exp_job: 1,
    drops: [{ item_id: 909, chance: 0.70, name: 'Jellopy' }]
};

const poring = new Monster('mob_1', mobTemplate);
const mCombat = poring.getComponent('combat');
const mAI = poring.getComponent('ai');

assert(mCombat.hp === 50, 'Poring HP = 50');
assert(mCombat.atkMin === 1 && mCombat.atkMax === 2, 'Poring ATK = 1-2');
assert(mCombat.aspd === 40, 'Poring ASPD = 40');
assert(mAI.state === 'IDLE', 'Poring starts IDLE');
assert(mAI.aiType === 'passive', 'Poring AI type = passive');
assert(mCombat.baseExpReward === 2, 'Poring base EXP reward = 2');

// --- Test Drop Entity ---
const drop = new DropEntity('drop_1', 909, 1, 15, 20);
assert(drop.itemId === 909, 'Drop item_id = 909');
assert(drop.isExpired() === false, 'Fresh drop not expired');
drop.spawnTime = Date.now() - 31000;
assert(drop.isExpired() === true, 'Drop expires after 30s');

// --- Test Combat System ---
// Setup a fake MapInstance with minimal server mock
const mockServer = {
    broadcast: (sessions, pid, payload) => {
        mockServer.lastBroadcast = { pid, payload };
    },
    send: (session, pid, payload) => {
        mockServer.lastUnicast = { pid, payload };
    }
};

const mapData = { id: 'test_map', width: 60, height: 60, collision: [], spawns: [], warps: [] };
const map = new MapInstance(mapData, mockServer);

// Manually set positions for combat
pMove.x = 10; pMove.y = 10;
const mMove = poring.getComponent('movement');
mMove.x = 11; mMove.y = 10; // 1 tile away

map.addEntity(player);
map.addEntity(poring);

// Attack!
CombatSystem.attemptAttack(player, poring, map);

assert(mCombat.hp < 50, 'Poring takes damage');
assert(mCombat.lastAttackerId === player.id, 'Poring tracks last attacker');
assert(mockServer.lastBroadcast.pid === PacketIDs.DAMAGE_NOTIFY, 'Combat broadcasts DAMAGE_NOTIFY');

// Kill the Poring
mCombat.hp = 1;
CombatSystem.attemptAttack(player, poring, map);
assert(mCombat.hp === 0, 'Poring HP reaches 0');

// --- Test Drop System ---
const dropSystem = new DropSystem(mockServer);
dropSystem.processDrops(poring, map, mobTemplate);

assert(mockServer.lastBroadcast.pid === PacketIDs.ENTITY_DEATH, 'DropSystem broadcasts ENTITY_DEATH');
const dropsList = mockServer.lastBroadcast.payload.drops;
assert(Array.isArray(dropsList), 'ENTITY_DEATH contains drops array');

// --- Test 3 Kills = Level Up ---
// Reset and simulate 3 kills
player.refreshStats();
pCombat.baseExp = 0;
pCombat.baseLevel = 1;
pCombat.statPoints = 0;

// Mock ExpSystem test
const ExpSystem = require('../server/src/systems/ExpSystem');

// Kill 1
mCombat.hp = 0; mCombat.lastAttackerId = player.id;
ExpSystem.processDeath(poring, map);
assert(pCombat.baseExp === 2, 'Kill 1: 2 base EXP');

// Kill 2 (simulate second poring)
const poring2 = new Monster('mob_2', mobTemplate);
const m2c = poring2.getComponent('combat');
m2c.hp = 0; m2c.lastAttackerId = player.id; m2c.baseExpReward = 2;
map.addEntity(poring2);
ExpSystem.processDeath(poring2, map);
assert(pCombat.baseExp === 4, 'Kill 2: 4 base EXP');

// Kill 3
const poring3 = new Monster('mob_3', mobTemplate);
const m3c = poring3.getComponent('combat');
m3c.hp = 0; m3c.lastAttackerId = player.id; m3c.baseExpReward = 2;
map.addEntity(poring3);
ExpSystem.processDeath(poring3, map);

assert(pCombat.baseLevel === 2, 'Kill 3: Base Level Up to 2');
assert(pCombat.statPoints === 1, 'Kill 3: Gained 1 stat point');
assert(pCombat.baseExp === 0, 'Kill 3: EXP rolled over correctly (6-6=0)');
assert(mockServer.lastUnicast.pid === PacketIDs.LEVEL_UP, 'LEVEL_UP packet sent');
assert(mockServer.lastUnicast.payload.new_level === 2, 'LEVEL_UP reports level 2');

// --- Summary ---
console.log(`\n=== UNIT RESULTS: ${passed} passed, ${failed} failed ===`);
process.exit(failed > 0 ? 1 : 0);