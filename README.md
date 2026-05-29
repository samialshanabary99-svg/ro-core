# 🏰 RO-CORE — STRATEGIC BUILD MASTER PLAN v2.0
> Ragnarok Online 2004-Inspired 2D MMORPG · Solo/Small-Team Execution Guide
> Last Revised: 2025 · Status: Pre-Production

---

## TABLE OF CONTENTS

1. [Vision Contract](#1-vision-contract)
2. [Architecture Philosophy](#2-architecture-philosophy)
3. [Full Milestone Roadmap (M0 → M6)](#3-full-milestone-roadmap)
4. [Phase Gates — Go / No-Go Criteria](#4-phase-gates)
5. [Dependency Map & Implementation Order](#5-dependency-map--implementation-order)
6. [Architecture Evolution Contract](#6-architecture-evolution-contract)
7. [Data-Driven Design Principles](#7-data-driven-design-principles)
8. [Security & Anti-Cheat Model](#8-security--anti-cheat-model)
9. [Performance Targets & Benchmarks](#9-performance-targets--benchmarks)
10. [Testing Strategy](#10-testing-strategy)
11. [Risk Register](#11-risk-register)
12. [Technical Debt Ledger](#12-technical-debt-ledger)
13. [Content Pipeline & Tooling](#13-content-pipeline--tooling)
14. [Database Evolution Strategy](#14-database-evolution-strategy)
15. [Networking Evolution Strategy](#15-networking-evolution-strategy)
16. [Observability & Monitoring](#16-observability--monitoring)
17. [Deployment & Operations](#17-deployment--operations)
18. [Definition of Done (Per Phase)](#18-definition-of-done-per-phase)
19. [Appendix: Full Packet Protocol v1](#19-appendix-full-packet-protocol-v1)
20. [Appendix: YAML Schema Reference](#20-appendix-yaml-schema-reference)

---

## 1. VISION CONTRACT

### North Star
Build the server architecture of a live MMORPG starting from a single map, one job, and one monster — but with every design decision made as if 500 players are online tomorrow.

### Non-Negotiable Principles
| # | Principle | Why It Matters |
|---|-----------|---------------|
| P1 | **Server is authoritative for all state** | Prevents every classic RO exploit (teleport hack, damage hack) |
| P2 | **Data lives in YAML, not code** | A game designer should add a new monster by editing a file, not a function |
| P3 | **Every packet routes through a factory** | Swap JSON → binary TCP in one file, zero game logic changes |
| P4 | **Components, never inheritance** | Adding SkillComponent or MountComponent tomorrow means zero rewrites |
| P5 | **No file exceeds 300 lines** | Forces separation of concerns; prevents monolith drift |
| P6 | **No magic numbers anywhere** | Every constant references `/shared/constants/` |
| P7 | **Every system is tested before integration** | A broken CombatSystem discovered at M3 costs 10x more to fix than at M2 |
| P8 | **Technical debt is named, tracked, and scheduled** | Debt you can't name will kill the project |

### Scope Contract (What This Plan Will NEVER Include)
Cash shop, gacha, pay-to-win systems, real-money transactions, personal data collection beyond what's strictly necessary for gameplay.

---

## 2. ARCHITECTURE PHILOSOPHY

### The "Camera + Simulator" Model
```
CLIENT = A dumb camera that shows what the server tells it to show.
         It predicts locally for smoothness, but NEVER owns ground truth.

SERVER = A deterministic physics simulator that owns all state.
         It processes input, never takes commands.
```

### Entity Component System (Why It Scales)
```
WRONG (inheritance):  Monster extends Entity
                      Poring extends Monster
                      → Adding "Boss" requires multiple inheritance hell

RIGHT (composition):  Entity { id, components: Map<string, Component> }
                      Poring = Entity + CombatComponent + MovementComponent + AIComponent
                      Baphomet = Entity + CombatComponent + MovementComponent + AIComponent + BossComponent
                      → Adding new behavior = new Component file only
```

### Tick-Based Determinism
```
Every 50ms (20Hz):
┌─────────────────────────────────────────────────────────────┐
│ 1. INGEST    Parse all queued packets from this tick        │
│ 2. AI        Run all AIComponents (at 200ms throttle)       │
│ 3. MOVE      Validate & advance all MovementComponents      │
│ 4. COMBAT    Resolve all queued attacks (damage, death)     │
│ 5. DROPS     Roll & spawn DropEntities from deaths          │
│ 6. EXPIRE    Remove stale drops, despawn timers             │
│ 7. BROADCAST Send delta state to all clients in map         │
└─────────────────────────────────────────────────────────────┘
Order is immutable. A CombatSystem can never run before MovementSystem.
```

---

## 3. FULL MILESTONE ROADMAP

### Overview Timeline
```
M0  Foundation        ████░░░░░░░░░░░░░░░░  1–2 weeks   (Shared layer + skeleton)
M1  Playable Core     ████████████░░░░░░░░  3–4 weeks   (Login to combat loop)
M2  Character Depth   ░░░░░░░░████████░░░░  3 weeks     (Skills, equipment, saving)
M3  World Expansion   ░░░░░░░░░░░░████████  4 weeks     (10 maps, 10 monsters, jobs)
M4  Social Layer      ░░░░░░░░░░░░░░░░████  3 weeks     (Party, trade, basic guild)
M5  Content Flood     ████████████████████  Ongoing     (50+ monsters, dungeons)
M6  Production Ready  ████████████████████  Ongoing     (Auth hardening, CDN, scaling)
```

---

### M0 — Foundation (Pre-Alpha Skeleton)
**Goal:** All shared code compiles. Server boots. Client connects. No gameplay.

| Deliverable | File(s) | Acceptance |
|-------------|---------|------------|
| Packet ID constants | `/shared/constants/packets.js` | All PIDs match spec, no duplicates |
| Game constants | `/shared/constants/game.js` | Formulas importable from both server and client |
| YAML data files | `/shared/data/*.yml` | All load without schema errors |
| Math utilities | `/shared/utils/math.js` | Unit tested: clamp, rand, distance, lerp |
| DB schema boots | `Database.js` | `node server/main.js` creates SQLite schema |
| WebSocket handshake | `Server.js` | Client connects, server logs session ID |
| Packet echo | `PacketFactory.js` | Server echoes `0x0064` back; client parses it |

**Blocked by:** Nothing  
**Blocks:** All of M1

---

### M1 — Playable Core (First Blood)
**Goal:** Two players can log in, see each other, and kill a Poring.

| Deliverable | Critical Path |
|-------------|---------------|
| Account creation + bcrypt login | → CharSelect → SpawnOnMap |
| Single Novice character slot | → Stats loaded from `jobs.yml` |
| `prt_fild01` map rendered | → Collision grid active |
| Server-side movement validation | → Client prediction with correction |
| 3 Poring spawns, respawn 5s | → `SpawnController` reading `maps.yml` |
| Click-to-attack + damage calc | → RO 2004 formula exact |
| Death → drops → pickup | → `DropSystem` + `PickupHandler` |
| EXP gain + level up | → `StatUpdate` + `LevelUp` packet |
| HP/SP bar, chat, damage numbers | → UI layer complete |

**Exit Criteria (Non-Negotiable):**
- [ ] Two simultaneous clients both see Poring die from Player A's attack
- [ ] Poring respawns at exact spawn coords after 5000ms (not 4999ms, not 5001ms)
- [ ] No packet triggers an unhandled exception on server
- [ ] SQLite character persists across server restart

---

### M2 — Character Depth
**Goal:** The Novice class feels like a real character with progression.

| Feature | New Systems Required |
|---------|---------------------|
| Stat point allocation (STR/AGI/etc.) | `StatSystem`, `StatAllocateHandler` |
| Basic item equip (Knife, Cotton Shirt) | `InventorySystem`, `EquipSlot` model |
| Equip bonus to ATK/DEF/stats | `EquipComponent`, stat recalc pipeline |
| Buff/debuff system stub | `BuffComponent` (stackable, timed) |
| 3 Novice starter skills | `SkillComponent`, `SkillTree` loader |
| NPC dialogue system stub | `NPCEntity`, `DialogueHandler` |
| Warp portal functional | `WarpHandler` (teleport between maps) |
| Character name display | `EntityRenderer` nameplate |

**Tech Introduced:**
- `InventorySystem` (server-side bag, slot management)
- `BuffComponent` (array of `{id, duration_ms, stats_delta}`)
- Second map (`prontera` stub, minimum 30×30)
- `SkillTree` YAML schema established

---

### M3 — World Expansion
**Goal:** The world feels alive with variety.

| Feature | Scale Target |
|---------|-------------|
| 3 new Jobs (Swordsman, Mage, Archer) | Jobs YAML + job change NPC |
| 10 new Monsters (various AI types) | `ai_aggressive.js`, `ai_boss.js` |
| 5 new Maps (fields + town) | Map loader handles all without code change |
| Monster skill usage | `MonsterSkillComponent` |
| Status effects (Stun, Poison, Slow) | `StatusEffectSystem` |
| MVP (boss-tier) monster | Rare spawn, enhanced drops |
| Party system (up to 12) | `PartySystem`, shared EXP split |
| Drop rate modifiers (item_drop_rate server var) | Config-driven, no code change needed |

**Architecture Decisions at M3:**
- Spatial hash bucket size may need tuning (profile at 100+ entities/map)
- `MapInstance` broadcast should switch to delta-only (skip unchanged entities)
- Consider map sharding if 3+ maps are active simultaneously

---

### M4 — Social Layer
**Goal:** Players have reasons to interact.

| Feature | Notes |
|---------|-------|
| Trade system (face-to-face) | Lockstep confirmation, no duping |
| Vending (player shops) | `VendingEntity` on map |
| Basic Guild (create, invite, chat) | `GuildSystem`, new DB table |
| Guild storage | Shared inventory per guild |
| Friends list + online status | `SocialSystem` |
| Whisper (private chat) | Route via session map |
| Mail system | Async item/zeny transfer |
| PvP toggle zones | Map flag in `maps.yml` |

**Security Focus at M4:**
- Every trade confirmed server-side (item exists, in bag, not equipped)
- Guild rank system prevents privilege escalation
- Rate-limit all social packets (whisper spam prevention)

---

### M5 — Content Flood (Ongoing)
**Goal:** Content team can add monsters/maps/items/skills without touching engine code.

**Targets:**
- 50+ monsters (all from YAML, zero new engine code)
- 10+ job classes (all from YAML skill tree)
- 20+ maps (all from map YAML + tileset)
- Instanced dungeons (party-only map instances)
- Seasonal events (time-gated content flags in config)

**Infrastructure Needed:**
- YAML validation CI pipeline (reject broken data on commit)
- Hot-reload for YAML on development server
- Content diff tool (show stat changes between YAML versions)

---

### M6 — Production Ready
**Goal:** The server can handle 100 concurrent players without degrading.

| Area | Target |
|------|--------|
| Auth | JWT refresh tokens, bcrypt cost 12 |
| Rate limiting | 50 packets/second/client hard cap |
| DB | Migrate SQLite → PostgreSQL for multi-process |
| Clustering | Node cluster module or PM2 for load balancing |
| CDN | Client assets served from CDN, not game server |
| Monitoring | Prometheus metrics, Grafana dashboard |
| Crash recovery | Process manager restarts server, state restored from DB |
| DDoS protection | Connection throttle at reverse proxy layer |

---

## 4. PHASE GATES

A gate must be 100% green before writing a single line of the next phase.

### Gate 0 → 1: Foundation Complete
```
[ ] node server/main.js starts without ANY errors or warnings
[ ] All YAML files parse successfully (run yaml-validator tool)
[ ] SQLite tables created correctly (verify with sqlite3 CLI)
[ ] WebSocket client connects, server logs connection
[ ] PacketFactory encodes AND decodes a round-trip correctly
[ ] All math.js functions pass unit tests
[ ] No file in /shared/ exceeds 300 lines
```

### Gate 1 → 2: M1 Playable
```
[ ] Two simultaneous clients tested — no state corruption
[ ] Poring AI states transition correctly: IDLE→CHASE→ATTACK→IDLE
[ ] Respawn timer accurate to ±50ms
[ ] Character data survives server restart (persistence works)
[ ] No memory leak after 1000 entity spawns/despawns (test with loop)
[ ] Combat formula matches RO 2004 reference values exactly:
       Novice (STR5, DEX5, LUK1) vs Poring: expected damage 4–7
[ ] Packet log shows zero undefined PIDs
[ ] Zero unhandled promise rejections in any code path
```

### Gate 2 → 3: M2 Character Depth
```
[ ] Equipping a Knife changes ATK value on StatUpdate
[ ] Skills fire via YAML lookup, no hardcoded skill IDs in handlers
[ ] Buff expires at exact duration (test with 1000ms buff)
[ ] Warp gate moves player to target map and spawns correctly
[ ] Second map is fully isolated (MapInstance per map confirmed)
[ ] Inventory full → pickup fails gracefully (no item dupe)
```

### Gate 3 → 4: M3 World Expansion
```
[ ] New monster added via YAML only, zero code changes required
[ ] New map added via YAML only, zero code changes required
[ ] New job added via YAML only, zero code changes required
[ ] Party EXP split is server-validated (no client can spoof share)
[ ] Boss monster respawn is correct (longer than normal mobs)
[ ] 50 concurrent entity movements in one map: server tick stays < 50ms
```

### Gate 4 → 5: M4 Social Layer
```
[ ] Trade confirmed: both sides must accept before items transfer
[ ] No item duplication possible via network timing attacks
[ ] Guild creation fails if name already taken
[ ] Whisper delivers to correct player only
[ ] Offline player cannot receive items (mail queued correctly)
```

---

## 5. DEPENDENCY MAP & IMPLEMENTATION ORDER

### Critical Path Diagram
```
shared/constants ──────────────────────────────────────────────────┐
shared/data/YAML ──────────────────────────────────────────────────┤
shared/utils/math ─────────────────────────────────────────────────┼──► Database.js
                                                                    │
Database.js ───────────────────────────────────────────────────────┤
PacketFactory.js ──────────────────────────────────────────────────┤
GameLoop.js ───────────────────────────────────────────────────────┼──► Server.js
                                                                    │
Components (Combat, Movement, AI) ─────────────────────────────────┤
Entity base class ─────────────────────────────────────────────────┤
Player, Monster, DropEntity ───────────────────────────────────────┤
                                                                    │
MapInstance ───────────────────────────────────────────────────────┤
SpawnController ───────────────────────────────────────────────────┤
Systems (Combat, Drop, Chat) ──────────────────────────────────────┼──► Handlers
ai_poring.js ──────────────────────────────────────────────────────┤
                                                                    │
Handlers (Login, Move, Combat, Chat) ──────────────────────────────┤
main.js (wiring) ──────────────────────────────────────────────────┘

CLIENT:
NetworkManager ──► PacketHandler ──► MapLoader ──► EntityRenderer ──► PlayerController
                                              └──► RemoteEntity
                                              └──► UI (HP, Stats, Chat, Damage)
```

### File Implementation Order With Explicit Dependencies

| Order | File | Depends On | Blocks |
|-------|------|------------|--------|
| 1 | `shared/constants/packets.js` | — | Everything |
| 2 | `shared/constants/game.js` | packets.js | Combat formulas |
| 3 | `shared/data/jobs.yml` | — | Player.js |
| 4 | `shared/data/monsters.yml` | — | Monster.js |
| 5 | `shared/data/maps.yml` | — | MapInstance.js |
| 6 | `shared/data/items.yml` | — | DropSystem.js |
| 7 | `shared/data/drops.yml` | items.yml | DropSystem.js |
| 8 | `shared/utils/math.js` | — | All formula code |
| 9 | `shared/utils/idgen.js` | — | All entity creation |
| 10 | `shared/utils/yamlLoader.js` | — | Server boot |
| 11 | `server/config.json` | — | Server.js |
| 12 | `server/src/core/Database.js` | config.json | LoginHandler |
| 13 | `server/src/core/PacketFactory.js` | packets.js | Server.js |
| 14 | `server/src/core/GameLoop.js` | config.json | Server.js |
| 15 | `server/src/core/Server.js` | All core | Handlers |
| 16 | `server/src/components/CombatComponent.js` | game.js | Entity.js |
| 17 | `server/src/components/MovementComponent.js` | math.js | Entity.js |
| 18 | `server/src/components/AIComponent.js` | — | Monster.js |
| 19 | `server/src/entities/Entity.js` | Components | Player, Monster |
| 20 | `server/src/entities/Player.js` | Entity, jobs.yml | MapInstance |
| 21 | `server/src/entities/Monster.js` | Entity, monsters.yml | SpawnController |
| 22 | `server/src/entities/DropEntity.js` | Entity, items.yml | DropSystem |
| 23 | `server/src/world/MapInstance.js` | Entity, math.js | SpawnController |
| 24 | `server/src/world/SpawnController.js` | MapInstance, Monster | Server.js |
| 25 | `server/src/systems/MovementSystem.js` | MapInstance, packets | CombatSystem |
| 26 | `server/src/systems/CombatSystem.js` | game.js, Entity | DropSystem |
| 27 | `server/src/systems/DropSystem.js` | drops.yml, DropEntity | CombatSystem |
| 28 | `server/src/systems/ExpSystem.js` | jobs.yml, Player | CombatSystem |
| 29 | `server/src/systems/ChatSystem.js` | MapInstance, packets | ChatHandler |
| 30 | `server/src/scripts/ai_poring.js` | game.js constants | Monster.js |
| 31 | `server/src/handlers/LoginHandler.js` | Database, packets | Server.js |
| 32 | `server/src/handlers/MapHandler.js` | MapInstance, packets | Server.js |
| 33 | `server/src/handlers/MovementHandler.js` | MovementSystem | Server.js |
| 34 | `server/src/handlers/CombatHandler.js` | CombatSystem | Server.js |
| 35 | `server/src/handlers/PickupHandler.js` | DropSystem | Server.js |
| 36 | `server/src/handlers/ChatHandler.js` | ChatSystem | Server.js |
| 37 | `server/main.js` | All above | — |

---

## 6. ARCHITECTURE EVOLUTION CONTRACT

This section defines **what will change** at each scale threshold and **what must NOT change** (the stable interface contracts).

### Stable Contracts (Never Rewrite These Interfaces)
```javascript
// PacketFactory — interface is forever:
PacketFactory.encode(pid, payload) → Buffer/string
PacketFactory.decode(raw) → { pid, payload }

// Entity — interface is forever:
entity.get(ComponentClass) → Component | null
entity.attach(component) → void
entity.detach(ComponentClass) → void

// MapInstance — interface is forever:
map.addEntity(entity) → void
map.removeEntity(entityId) → void
map.getEntitiesInRadius(x, y, radius) → Entity[]
map.broadcast(pid, payload, excludeId?) → void
```

### Evolution Triggers & Actions

| Trigger | Action | Files Changed |
|---------|--------|---------------|
| > 5 maps active | Map sharding: each MapInstance in worker thread | `Server.js`, `MapInstance.js` |
| > 50 entities/map | Spatial hash bucket resize (10→5 tiles) | `MapInstance.js` only |
| > 100 concurrent users | Delta broadcast (skip unchanged entities) | `MapInstance.broadcast()` only |
| > 500 concurrent users | Migrate SQLite → PostgreSQL | `Database.js` only (interface unchanged) |
| > 1000 concurrent users | Horizontal scaling with shared Redis state | New `StateSync.js` module |
| Binary protocol needed | Swap JSON → MessagePack in PacketFactory | `PacketFactory.js` only |
| TypeScript migration | Add `.d.ts` JSDoc types first, then migrate | No game logic changes |

### The "Zero Rewrite" Promise
If the architecture contracts above are respected, migrating from:
- JSON → Binary packets: 1 file change
- SQLite → Postgres: 1 file change
- Single server → Clustered: 2 file changes

This is only true if **no game system reaches into PacketFactory or Database directly** — everything goes through the interface.

---

## 7. DATA-DRIVEN DESIGN PRINCIPLES

### The YAML First Rule
Before writing a single line of code for a new feature, ask:
> "Can a designer add this to the game by only editing a YAML file?"

If yes → the code is done correctly.  
If no → you have hardcoded something that belongs in YAML.

### YAML Schema Contracts

Every YAML file must have a companion JSON Schema file in `/tools/schemas/`:

```
/tools/schemas/
├── jobs.schema.json
├── monsters.schema.json
├── items.schema.json
├── maps.schema.json
└── drops.schema.json
```

Server boot sequence:
```
1. Load schema → 2. Validate YAML against schema → 3. Reject boot if invalid
```

This means a typo in `monsters.yml` crashes the server at boot, not during gameplay.

### Data Versioning
Every YAML file has a version header:
```yaml
# @version 1.0.0
# @last_modified 2025-01-01
# @author <designer_name>
monsters:
  poring:
    ...
```

The server logs the version of every data file on boot. If two servers have different YAML versions, they are incompatible.

### Balance Change Workflow
```
1. Edit YAML file
2. Run: node tools/validate.js (schema + reference checks)
3. Run: node tools/diff.js (shows stat delta from previous version)
4. Restart dev server
5. QA test specific affected content
6. Commit with message: "balance: poring HP 50→60, see CHANGELOG.md"
```

---

## 8. SECURITY & ANTI-CHEAT MODEL

### Threat Model (What Attackers Will Try)
| Attack | Server Defense |
|--------|----------------|
| Teleport hack (fake WalkRequest with far coords) | Server validates distance per tick; max movement = speed × tick_delta |
| Damage hack (fake AttackRequest with high damage) | Damage is 100% server-calculated; client sends target_id only |
| Speed hack (send WalkRequest faster than ASPD) | Rate-limit WalkRequests; server ignores excess |
| Item dupe (disconnect during pickup) | Pickup uses DB transaction: remove drop + add to inventory atomically |
| Packet replay (resend old AttackRequest) | Session tokens are per-session; stale packets from dead sessions are dropped |
| Inventory overflow | Server validates bag capacity before any pickup or item transfer |
| Account takeover | bcrypt cost 12; rate-limit login attempts to 5/minute |
| MapInstance pollution | Entities bound to MapInstance UUID; cross-map entity reference = error |

### Packet Validation Rules (PacketFactory enforces ALL of these)
```javascript
// Every incoming packet must:
1. Have a valid session token (attached at WebSocket session level)
2. Have a known PID (reject unknown PIDs immediately)
3. Have correct payload schema (Zod or manual validation)
4. Pass rate limiting (max 60 packets/sec/client)
5. Originate from the correct game state (can't send AttackRequest from LoginScreen)
```

### Session State Machine
```
UNAUTHENTICATED  → (0x0064 LoginRequest)  → AUTHENTICATED
AUTHENTICATED    → (0x006B CharSelect)    → CHAR_SELECTED
CHAR_SELECTED    → (0x0072 EnterMap)      → IN_GAME
IN_GAME          → (disconnect)           → UNAUTHENTICATED (save + cleanup)

Any packet arriving in wrong state → disconnect client immediately
```

### Anti-Exploit Checklist (Per M1 Milestone)
- [ ] WalkRequest: validate `(new_pos - old_pos).length() <= max_tiles_per_tick`
- [ ] AttackRequest: server checks attacker is alive, target is alive, range valid
- [ ] PickupRequest: server checks drop_uid exists and is not already claimed
- [ ] LoginRequest: rate-limited, bcrypt verify, no timing oracle leak
- [ ] ChatMessage: sanitize for XSS, max 200 chars, rate-limit 3/sec

---

## 9. PERFORMANCE TARGETS & BENCHMARKS

### Server Performance Targets

| Metric | M1 Target | M3 Target | M6 Target |
|--------|-----------|-----------|-----------|
| Tick execution time | < 5ms | < 20ms | < 40ms |
| Concurrent players | 10 | 100 | 500 |
| Entities per map | 50 | 200 | 500 |
| Packets processed/tick | 200 | 2000 | 10000 |
| DB write latency | < 5ms | < 5ms | < 10ms |
| Memory per player | < 50KB | < 100KB | < 200KB |
| Server startup time | < 2s | < 5s | < 10s |

### How to Measure
```bash
# Tick profiler (add to GameLoop.js):
const tickStart = process.hrtime.bigint();
// ... tick logic ...
const tickMs = Number(process.hrtime.bigint() - tickStart) / 1e6;
if (tickMs > 40) console.warn(`[PERF] Slow tick: ${tickMs.toFixed(2)}ms`);

# Memory monitor (add to Server.js):
setInterval(() => {
  const mb = process.memoryUsage().heapUsed / 1024 / 1024;
  if (mb > 512) console.warn(`[PERF] High memory: ${mb.toFixed(1)}MB`);
}, 30000);
```

### Client Performance Targets

| Metric | Target |
|--------|--------|
| FPS (modern PC) | 60 stable |
| FPS (low-end PC) | 30 minimum |
| Input-to-visual latency | < 16ms (1 frame) |
| Network interpolation smoothness | No visible jitter at < 150ms RTT |
| Map load time | < 1 second |
| Entity spawn (100 entities) | < 100ms |

### Profiling Checkpoints
Run these before every Gate:
1. `node --prof server/main.js` + `node --prof-process` to find hot functions
2. Godot built-in profiler: check draw calls, physics steps
3. Simulate 20 simultaneous clients with a test script before claiming any concurrent player target

---

## 10. TESTING STRATEGY

### Testing Pyramid

```
        ┌─────────────────┐
        │   E2E Tests      │  ← Fewest: Full client-server flow
        │   (5–10 flows)   │
        ├─────────────────┤
        │ Integration Tests│  ← Medium: System + DB + network
        │   (20–30 cases)  │
        ├─────────────────┤
        │   Unit Tests     │  ← Most: Pure functions, formulas
        │  (50–100 cases)  │
        └─────────────────┘
```

### Unit Test Requirements (M1)

Every function in `/shared/utils/math.js` must have a test:
```javascript
// /tests/unit/math.test.js
test('clamp(5, 0, 10) === 5')
test('clamp(-1, 0, 10) === 0')
test('clamp(15, 0, 10) === 10')
test('distance(0,0, 3,4) === 5')    // Pythagorean triple
test('lerp(0, 10, 0.5) === 5')
```

Every combat formula must have a test:
```javascript
// /tests/unit/combat.test.js
test('Novice ATK (STR=5): 2 + 5 + floor(5/10)^2 = 7')
test('HP formula (BaseLv=1, VIT=1): 40 + 5 + 2 = 47')
test('ASPD interval (ASPD=40): (2000 - 40*10) = 1600ms')
test('Hit chance (DEX=50, target_Flee=20): clamp(100+50-20, 5, 100) = 100')
test('Damage minimum is 1 even when target_DEF > ATK')
test('Crit ignores DEF: Crit = ATK + rand(0, ATK*0.2), no DEF subtraction')
```

### Integration Tests (M1)

```javascript
// /tests/integration/login.test.js
test('Register → Login → Enter Map flow completes without error')
test('Wrong password returns 0x0064 error code, no session created')
test('Duplicate username returns error, first account unchanged')

// /tests/integration/combat.test.js
test('Player attacks Poring → DamageNotify → HP reduced on server')
test('Poring death → drops spawned at correct coordinates')
test('Pickup → inventory updated → drop removed from map')
test('EXP gain → level up at 6 base EXP → LevelUp packet sent')

// /tests/integration/movement.test.js
test('Walk to (5,5) → server validates → WalkNotify broadcast')
test('Walk to blocked tile → server rejects → StopMove sent')
test('Walk off map bounds → rejected, position clamped')
```

### E2E Test Scenarios (M1)

These are manual test runs but must be documented as scripts for later automation:
```
SCENARIO: First Kill
1. Register new account "test_player_1"
2. Login → CharSelect → EnterMap
3. Locate Poring at spawn (15,20)
4. Walk to attack range
5. Click Poring
6. Observe: DamageNotify received, HP bar updates
7. Kill Poring
8. Observe: EntityDeath with drops
9. Walk to drop
10. Observe: PickupNotify, drop disappears
11. Expected result: Inventory shows Jellopy or Apple

SCENARIO: Concurrency
1. Open 2 clients simultaneously
2. Client A kills Poring
3. Verify Client B receives EntityDeath packet
4. Verify drop is visible to both clients
5. Client A picks up drop
6. Verify drop disappears for Client B too
7. Client B tries to pick up same drop → receives "already taken" result
```

### Test Infrastructure
```
/tests/
├── /unit/
│   ├── math.test.js
│   ├── combat.test.js
│   └── packets.test.js
├── /integration/
│   ├── login.test.js
│   ├── movement.test.js
│   └── combat.test.js
├── /e2e/
│   └── scenarios.md   (manual scripts for now)
└── /load/
    └── simulate_clients.js  (20 bots, stress test)
```

Test runner: `node --test` (Node.js 20 built-in, zero dependencies).

---

## 11. RISK REGISTER

### Risk Matrix

| ID | Risk | Probability | Impact | Mitigation |
|----|------|------------|--------|------------|
| R1 | Godot 4.x WebSocket API changes in minor version | Medium | High | Pin Godot version, test on upgrade |
| R2 | SQLite write contention under load | Medium | High | Batch writes, use WAL mode |
| R3 | uWebSockets.js binary incompatibility (Node upgrade) | Low | High | Pin Node version, fallback to `ws` |
| R4 | Memory leak in MapInstance (entity references not cleaned up) | High | Medium | Explicit cleanup in despawn, test with leak detection |
| R5 | Tick loop drift over time (setInterval is not precise) | High | Medium | Use `hrtime` delta, skip ticks if overloaded |
| R6 | YAML data errors shipped to production | Medium | High | Validate YAML at server boot (crash if invalid) |
| R7 | Combat formula deviation from RO 2004 reference | Low | Medium | Unit test every formula against reference values |
| R8 | Client prediction desync under poor network | Medium | Medium | Lerp correction, max 100ms |
| R9 | Scope creep beyond M1 before M1 is stable | High | High | Hard scope lock — gate system enforced |
| R10 | No automated tests → regression on every change | High | High | Enforce unit tests before any Gate passes |

### Contingency Plans

**R4 (Memory Leak):** Add leak detection test to Gate 1 → 2:
```javascript
// Run 1000 spawn/despawn cycles, check heapUsed delta < 1MB
```

**R5 (Tick Drift):** Implement compensated timer:
```javascript
let lastTick = Date.now();
function tick() {
  const now = Date.now();
  const delta = now - lastTick;
  lastTick = now;
  // skip tick if server is more than 100ms behind
  if (delta > 100) console.warn('[LOOP] Tick skipped: ' + delta + 'ms late');
  setTimeout(tick, Math.max(0, TICK_MS - (Date.now() - now)));
}
```

**R9 (Scope Creep):** Post this rule at top of every code session:
> "Does this feature ship in M1? If no, add it to the M2 backlog file and close the editor."

---

## 12. TECHNICAL DEBT LEDGER

This section is crucial. Track every shortcut taken so it doesn't become permanent.

### Known Debt at M1 (Intentional Shortcuts)

| ID | Debt | Why Accepted | When to Pay | Effort |
|----|------|-------------|-------------|--------|
| D1 | JSON packets (should be binary) | Faster debugging | M6 (production) | 2 days |
| D2 | Single SQLite file (should be Postgres) | Zero config | M6 (> 100 users) | 3 days |
| D3 | No JWT refresh tokens (plain session token) | Simple to start | M4 (before social) | 1 day |
| D4 | No rate limiting per-packet (just per-connection) | MVP speed | M2 | 1 day |
| D5 | Linear entity scan for AI targeting (should be spatial query) | Only 3 entities | M3 (> 20 entities) | 2 hours |
| D6 | No YAML hot-reload (requires restart) | DevEx is fine | M5 | 1 day |
| D7 | No client-side map cache (reloads every login) | Only 1 map | M3 | 1 day |
| D8 | Placeholder sprites (colored rectangles) | Art not needed yet | M5 (content phase) | Weeks (art work) |
| D9 | No packet compression | Low traffic | M6 | 2 hours |
| D10 | No graceful shutdown (SIGTERM handler missing) | Dev only | M2 | 2 hours |

### Debt Payment Rules
- Paying debt is a dedicated commit, not a "while I'm in here" change
- Debt paid = tests updated, no regressions
- Never pay debt during a feature sprint (separate PR/branch)

---

## 13. CONTENT PIPELINE & TOOLING

### The Tools Directory

```
/tools/
├── validate.js          # Validate all YAML against JSON schemas
├── diff.js              # Show stat changes between YAML versions
├── monster-builder.js   # Interactive CLI: "Add new monster" wizard
├── map-editor/          # (M3) Simple tile map editor (electron or browser)
├── drop-calculator.js   # Given a set of mobs, show expected drop rates
└── schemas/             # JSON Schema files for every YAML type
```

### Adding a New Monster (Zero Code Workflow — M3 Goal)
```bash
# 1. Run the monster builder wizard
node tools/monster-builder.js

# Prompts:
# Monster ID (1–9999): 1113
# Name: Willow
# HP: 40
# ATK min/max: 1 / 3
# DEF: 0, Flee: 5, Hit: 2, ASPD: 30, Speed: 180ms
# AI type (passive/aggressive/boss): passive
# Base EXP: 1, Job EXP: 1
# Add drop? item_id: 701 (Tree Root), chance: 55%
# Add drop? item_id: 512 (Apple), chance: 5%
# Done!

# 2. Wizard appends to monsters.yml and drops.yml automatically
# 3. Validate
node tools/validate.js
# ✓ monsters.yml: 2 entries — valid
# ✓ drops.yml: 4 entries — valid

# 4. Add spawn point to a map.yml spawn list
# 5. Restart dev server — Willow appears in world
```

### Adding a New Map
```yaml
# Append to maps.yml:
prt_fild02:
  id: "prt_fild02"
  width: 80
  height: 80
  tile_size: 32
  collision: []       # Tool generates from tileset
  spawns:
    - { mob_id: 1002, x: 20, y: 20, radius: 8, amount: 3, delay: 5000 }
    - { mob_id: 1113, x: 50, y: 60, radius: 6, amount: 2, delay: 8000 }
  warps:
    - { x: 0, y: 40, target_map: "prt_fild01", target_x: 58, target_y: 30 }
```

No code changes. Server loads it. Client loads it. Done.

---

## 14. DATABASE EVOLUTION STRATEGY

### SQLite → PostgreSQL Migration Path

The `Database.js` interface must never expose SQL directly to game systems:

```javascript
// CORRECT — game system calls:
await db.saveCharacter(characterData)  // abstracted
await db.getCharacter(charId)           // abstracted

// WRONG — game system calls:
await db.query('SELECT * FROM characters WHERE id = ?', [charId])
```

This means the migration from SQLite to Postgres is a single file swap in `Database.js` with zero changes to any handler, system, or entity.

### Schema Migration Strategy

Use sequential numbered migration files:
```
/server/migrations/
├── 001_initial_schema.sql
├── 002_add_inventory.sql
├── 003_add_guild_tables.sql
└── ...
```

Server on boot:
1. Check `schema_version` table
2. Run any migrations with version > current
3. Update `schema_version`
4. Continue boot

Never manually ALTER tables in production. Always use migrations.

### Character Save Strategy

```
SAVE TRIGGERS (in priority order):
1. Logout → immediate save + session cleanup
2. Level up → save within this tick
3. Map change → save before instance change
4. Auto-save → every 60 seconds, non-blocking
5. Server shutdown → save ALL characters in batch transaction
```

Save is always wrapped in a transaction:
```javascript
const save = db.transaction((char) => {
  updateCharacterStmt.run(char);
  updateInventoryStmt.run(char.inventory);
});
// If any part fails, entire save rolls back — no partial state
```

---

## 15. NETWORKING EVOLUTION STRATEGY

### Phase 1: JSON over WebSocket (M1)
```
Pros:  Human-readable, easy to debug, zero setup
Cons:  ~5x larger packets than binary, more parse overhead
Use:   Development and M1/M2 production
```

### Phase 2: MessagePack over WebSocket (M4–M5)
```
Pros:  Binary, 30–50% smaller than JSON, same schema
Cons:  Not human-readable (use debug mode to log JSON)
Use:   When packet overhead becomes measurable
Migration: PacketFactory.js only — 1 file
```

### Phase 3: Binary TCP with Custom Protocol (M6+)
```
Pros:  Lowest latency, smallest packets
Cons:  Custom client + server parser, no browser WebSocket
Use:   Standalone client only (Godot desktop build)
Migration: PacketFactory + NetworkManager.gd — 2 files
```

### Packet Versioning
Every packet format change must be backwards-compatible for 1 version:
```json
{"pid": "0x0078", "v": 2, "payload": {...}}
```
Server supports `v1` and `v2` simultaneously during transition period.

### Connection Resilience (M2)
```
Client:
- Reconnect with exponential backoff: 1s, 2s, 4s, 8s, 16s, stop
- On reconnect: send session token → server restores state
- Show "Reconnecting..." UI, freeze input during reconnect

Server:
- Keep session alive 10 seconds after disconnect (grace period)
- On reconnect with valid token: restore player position from MapInstance
- After grace period: save + remove from map
```

---

## 16. OBSERVABILITY & MONITORING

### Log Levels (Used From Day 1)
```javascript
// /shared/utils/logger.js
const LOG_LEVELS = { DEBUG: 0, INFO: 1, WARN: 2, ERROR: 3 };

logger.debug('[MapInstance] Entity 0x4a spawned at (15,20)');    // Verbose
logger.info('[Server] Client connected: session_abc123');         // Normal ops
logger.warn('[Combat] Tick took 45ms — approaching limit');       // Threshold hit
logger.error('[Database] Save failed for char_id 7: ' + err);   // Needs attention
```

### Key Metrics to Track (From M1)
```
SERVER METRICS:
├── tick_duration_ms        (histogram, warn > 40ms, error > 50ms)
├── connected_clients       (gauge)
├── entities_per_map        (gauge, per map)
├── packets_per_second      (counter)
├── db_write_latency_ms     (histogram)
└── unhandled_errors_total  (counter, should always be 0)

CLIENT METRICS:
├── fps                     (gauge, warn < 30)
├── network_rtt_ms          (gauge, show in debug UI)
├── server_corrections      (counter, high = bad prediction)
└── interpolation_skips     (counter, high = network jitter)
```

### Debug Mode
Add `?debug=1` to WebSocket URL → server sends extra diagnostic packets:
```json
{"pid": "0xDEBU", "payload": {
  "tick_ms": 3.2,
  "entities": 7,
  "packets_this_tick": 12
}}
```
Client shows this in a debug overlay (toggle with F12).

---

## 17. DEPLOYMENT & OPERATIONS

### Development Environment
```bash
# Prerequisites
node --version   # 20+
sqlite3 --version
godot --version  # 4.2+

# Start server (dev mode with hot reload)
cd /ro-core/server
node --watch main.js   # Node 20 built-in watch mode

# Validate data files
node ../tools/validate.js

# Run tests
node --test tests/unit/
node --test tests/integration/
```

### Environment Config Strategy
```
/server/config.json          ← Dev defaults (committed to repo)
/server/config.local.json    ← Local overrides (gitignored)
/server/config.prod.json     ← Production (gitignored, in secrets manager)
```

Server loads: `config.json` → merge `config.local.json` → merge `NODE_ENV=prod ? config.prod.json`.

### Production Deployment (M6)
```
Infrastructure:
├── Reverse Proxy: Nginx (TLS termination, WebSocket upgrade)
├── Game Server: PM2 cluster (2-4 workers)
├── Database: PostgreSQL (RDS or dedicated VM)
├── File Server: Nginx static (client assets)
└── Monitoring: Prometheus + Grafana

Deployment process:
1. git pull on server
2. node tools/validate.js  (abort if invalid)
3. node server/migrations/run.js  (apply new migrations)
4. pm2 reload ro-core --update-env  (zero-downtime reload)
5. Monitor: tick_duration_ms for 5 minutes post-deploy
```

### Graceful Shutdown (Must Implement by M2)
```javascript
process.on('SIGTERM', async () => {
  logger.info('[Server] SIGTERM received — graceful shutdown');
  // 1. Stop accepting new connections
  // 2. Broadcast "server restarting in 30s" to all clients
  // 3. Wait 5 seconds for in-flight packets to drain
  // 4. Save ALL connected characters in batch transaction
  // 5. Close all WebSocket connections
  // 6. Close DB connection
  // 7. process.exit(0)
});
```

---

## 18. DEFINITION OF DONE (PER PHASE)

A feature is DONE when ALL of the following are true:
```
[ ] Code compiles/runs without errors or warnings
[ ] All relevant unit tests pass
[ ] All relevant integration tests pass
[ ] File is under 300 lines (split if not)
[ ] No magic numbers (all constants referenced from /shared/constants/)
[ ] No TODO comments without a tracked debt entry in Technical Debt Ledger
[ ] Error paths are handled (try/catch, packet validation, DB failure)
[ ] Memory cleanup path exists (entity despawn frees all references)
[ ] Function has JSDoc type annotations (server) or static types (client)
[ ] Change is tested against the Phase Gate criteria before moving on
```

### The "Ship It" Checklist (Before Any Gate)
```
[ ] Boot server from scratch (no existing DB) — works
[ ] Boot server with existing DB — works
[ ] Connect 2 clients simultaneously — no state corruption
[ ] Kill server with Ctrl+C — characters saved, no data loss
[ ] Run all tests — all pass
[ ] Check all files — none over 300 lines
[ ] Check all constants — none hardcoded
[ ] Check Technical Debt Ledger — new debt is documented
```

---

## 19. APPENDIX: FULL PACKET PROTOCOL v1

### Packet Envelope
```json
{ "pid": "0x00XX", "v": 1, "seq": 12345, "payload": {} }
```
- `pid`: Packet ID (string, for JSON readability)
- `v`: Protocol version (increment on breaking changes)
- `seq`: Sequence number (client increments; server uses for ordering)

### Full Packet Reference

| PID | Name | Direction | Payload |
|-----|------|-----------|---------|
| 0x0064 | LoginRequest | C→S | `{username, password}` |
| 0x0065 | LoginSuccess | S→C | `{session_token, char_slots:[]}` |
| 0x0066 | LoginFail | S→C | `{reason: "wrong_password"|"banned"|"already_online"}` |
| 0x0067 | RegisterRequest | C→S | `{username, password}` |
| 0x0068 | RegisterResult | S→C | `{success, reason?}` |
| 0x006B | CharSelect | C→S | `{char_id}` |
| 0x006C | CharCreate | C→S | `{name, job_id}` |
| 0x0072 | EnterMap | S→C | `{map_name, x, y}` |
| 0x0078 | EntitySpawn | S→C | `{entity_type, id, name, sprite, x, y, dir, speed, hp_percent}` |
| 0x0080 | EntityDespawn | S→C | `{id}` |
| 0x0085 | WalkRequest | C→S | `{x, y}` |
| 0x0086 | WalkNotify | S→C | `{id, x, y, dir, speed}` |
| 0x0087 | StopMove | S→C | `{id, x, y}` |
| 0x0088 | AttackRequest | C→S | `{target_id}` |
| 0x0089 | DamageNotify | S→C | `{attacker_id, target_id, damage, is_crit, hp_left, max_hp}` |
| 0x0090 | EntityDeath | S→C | `{id, drops:[{uid, item_id, x, y}]}` |
| 0x0091 | PickupRequest | C→S | `{drop_uid}` |
| 0x0092 | PickupResult | S→C | `{drop_uid, item_id, amount, result: "ok"|"taken"|"full"}` |
| 0x0093 | ChatMessage | S→C/C→S | `{scope:"map"|"say", message, sender_id, sender_name}` |
| 0x0094 | StatUpdate | S→C | `{str,agi,vit,int,dex,luk,hp,max_hp,sp,max_sp,base_exp,next_base_exp,job_exp,next_job_exp,stat_points,base_level,job_level}` |
| 0x0095 | LevelUp | S→C | `{type:"base"|"job", new_level}` |
| 0x0096 | EntityMove | S→C | `{id, from_x, from_y, to_x, to_y, move_start_ms}` |
| 0x0097 | DropSpawn | S→C | `{uid, item_id, item_name, x, y}` |
| 0x0098 | DropDespawn | S→C | `{uid}` |
| 0xFFFF | Ping | C↔S | `{timestamp}` |

---

## 20. APPENDIX: YAML SCHEMA REFERENCE

### monsters.yml Full Schema
```yaml
monsters:
  <mob_key>:
    id: integer          # Unique mob ID (1–9999)
    name: string
    sprite: string       # Sprite key for client asset loader
    hp: integer
    atk_min: integer
    atk_max: integer
    def: integer
    flee: integer
    hit: integer
    aspd: integer        # 0–199. Attack interval = (2000 - aspd*10) ms
    speed: integer       # Milliseconds per tile
    size: string         # small | medium | large
    element: string      # neutral | fire | water | wind | earth | ...
    race: string         # formless | undead | brute | plant | insect | fish | demon | demihuman | angel | dragon
    ai_type: string      # passive | aggressive | assist | boss
    exp_base: integer
    exp_job: integer
    drops:
      - item_id: integer
        chance: float    # 0.0 to 1.0
        name: string     # Informational only
    mvp_drops:           # Optional, for boss mobs
      - item_id: integer
        chance: float
```

### jobs.yml Full Schema
```yaml
jobs:
  <job_key>:
    id: integer          # 0=Novice, 1=Swordsman, 2=Mage, etc.
    name: string
    inherit_from: string # Optional: "novice" for 2nd class jobs
    max_base_level: integer
    max_job_level: integer
    base_hp: integer
    base_sp: integer
    hp_factor: integer   # HP gained per base level
    sp_factor: integer   # SP gained per base level
    hp_job_factor: integer # HP gained per job level (for 2nd class)
    aspd_table:          # Map of weapon type → base ASPD
      unarmed: integer
      sword: integer
      # ...
    stat_bonus:
      str: integer
      agi: integer
      vit: integer
      int: integer
      dex: integer
      luk: integer
    skill_tree:
      - skill_id: string
        max_level: integer
        requires: []     # Skill prerequisites
```

### maps.yml Full Schema
```yaml
maps:
  <map_id>:
    id: string
    display_name: string
    width: integer
    height: integer
    tile_size: integer   # pixels
    tileset: string      # Asset key
    flags:               # Optional map behavior flags
      pvp: boolean
      no_save: boolean
      no_warp: boolean
      no_memo: boolean
    collision: []        # 2D array [height][width]: 0=walk, 1=block, 2=water
    music: string        # BGM asset key
    weather: string      # none | rain | snow | sakura
    spawns:
      - mob_id: integer
        x: integer
        y: integer
        radius: integer
        amount: integer
        delay: integer   # Respawn milliseconds
    warps:
      - x: integer
        y: integer
        width: integer   # Warp zone width (default 1)
        height: integer  # Warp zone height (default 1)
        target_map: string
        target_x: integer
        target_y: integer
    npcs:                # (M2+)
      - npc_id: string
        x: integer
        y: integer
        dir: integer
```

---

## QUICK REFERENCE CARD

```
══════════════════════════════════════════════════════════════
BEFORE WRITING CODE: Check Phase Gate for current phase
BEFORE COMMITTING:   Run node --test tests/
BEFORE NEW FEATURE:  Does it belong to current Milestone?
BEFORE SKIPPING:     Document in Technical Debt Ledger
AFTER EACH PHASE:    Run full "Ship It" Checklist
══════════════════════════════════════════════════════════════

COMBAT FORMULAS (never hardcode, always reference game.js):
  ATK   = 2 + STR + floor(STR/10)^2
  HP    = 40 + BaseLv*5 + VIT*2
  SP    = 11 + BaseLv*2 + INT*2
  FLEE  = 1 + LUK + AGI
  HIT   = 100 + DEX
  HIT%  = clamp(100 + attacker_HIT - target_FLEE, 5, 100)
  CRIT% = 1 + floor(LUK * 0.3)
  DMG   = (ATK + rand(0, ATK*0.2)) - DEF  [min 1]
  ASPD  = 156 - (WeaponDelay * (1 - AGI/250))
  INTERVAL_MS = 2000 - (ASPD * 10)

TICK ORDER (immutable):
  1. Ingest → 2. AI → 3. Move → 4. Combat → 5. Drops → 6. Expire → 7. Broadcast
══════════════════════════════════════════════════════════════
```

---

*"Write the first monster as if you're writing the thousandth."*
