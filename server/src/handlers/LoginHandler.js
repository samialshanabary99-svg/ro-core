const crypto = require('crypto');
const { PacketIDs } = require('../../../shared/constants/packets');
const Player = require('../entities/Player');

/**
 * LoginHandler
 * Processes authentication requests, profile registrations, session instantiation,
 * and character selection with automatic map entry.
 */
class LoginHandler {
    /**
     * @param {Server} server 
     * @param {Database} db 
     * @param {DataLoader} dataLoader 
     * @param {Map<string, MapInstance>} worldMaps 
     */
    static register(server, db, dataLoader, worldMaps) {
        
        // 1. Handle Account Authentication / Registration (0x0064)
        server.registerHandler(PacketIDs.LOGIN_REQUEST, (session, payload) => {
            const { username, password } = payload;
            if (!username || !password || username.trim().length < 4) {
                server.send(session, PacketIDs.LOGIN_FAIL, { reason: 'Invalid parameters provided.' });
                return;
            }

            const cleanUser = username.trim().toLowerCase();
            const passwordHash = crypto.createHash('sha256').update(password).digest('hex');

            let account = db.statements.getAccountByUsername.get(cleanUser);

            if (!account) {
                // Auto-create account container structure if missing
                db.statements.createAccount.run(cleanUser, passwordHash, Date.now());
                account = db.statements.getAccountByUsername.get(cleanUser);
                console.log(`[Login] New account auto-registered: ${cleanUser}`);
            } else if (account.password_hash !== passwordHash) {
                server.send(session, PacketIDs.LOGIN_FAIL, { reason: 'Invalid credentials.' });
                return;
            }

            session.accountId = account.id;

            // Retrieve associated characters
            let chars = db.statements.getCharactersByAccount.all(account.id);
            
            // CRITICAL FIX: Auto-create a default Novice if account has no characters
            // This ensures E2E tests and new accounts can immediately select a character
            if (chars.length === 0) {
                db.statements.createCharacter.run(account.id, 'Novice', Date.now());
                chars = db.statements.getCharactersByAccount.all(account.id);
                console.log(`[Login] Auto-created default Novice character for account: ${cleanUser}`);
            }

            const charactersPayload = chars.map(c => ({
                id: c.id,
                name: c.name,
                job_id: c.job_id,
                base_level: c.base_level,
                job_level: c.job_level,
                hp: c.hp,
                max_hp: c.max_hp
            }));

            server.send(session, PacketIDs.LOGIN_SUCCESS, {
                account_id: account.id,
                characters: charactersPayload
            });
        });

        // 2. Handle Character Selection & Map Spawning (0x006B)
        server.registerHandler(PacketIDs.CHAR_SELECT, (session, payload) => {
            if (!session.accountId) return;

            const { char_id } = payload;
            const charData = db.statements.getCharacterById.get(char_id);

            if (!charData || charData.account_id !== session.accountId) {
                console.warn(`[Login] Session unauthorized for target entity ID: ${char_id}`);
                return;
            }

            session.characterId = char_id;
            
            const targetMapId = charData.map_name;
            const mapInstance = worldMaps.get(targetMapId);
            if (!mapInstance) {
                console.error(`[Login] Selected character spawned on an unrecognized map layout: ${targetMapId}`);
                return;
            }

            session.activeMap = mapInstance;

            // Fetch Job Specifications via Data Loader cache
            const jobTemplate = dataLoader.getJob(charData.job_id) || dataLoader.getJob(0);
            
            // Build live authoritative Player Entity
            const playerEntity = new Player(`char_${charData.id}`, charData.name, jobTemplate);
            
            // Populate Entity data variables using Database states
            const move = playerEntity.getComponent('movement');
            if (move) {
                move.x = charData.x;
                move.y = charData.y;
                move.targetX = charData.x;
                move.targetY = charData.y;
            }

            const combat = playerEntity.getComponent('combat');
            if (combat) {
                combat.baseLevel = charData.base_level;
                combat.jobLevel = charData.job_level;
                combat.baseExp = charData.base_exp;
                combat.jobExp = charData.job_exp;
                combat.str = charData.str;
                combat.agi = charData.agi;
                combat.vit = charData.vit;
                combat.int = charData.int;
                combat.dex = charData.dex;
                combat.luk = charData.luk;
                combat.statPoints = charData.stat_points;
                
                playerEntity.refreshStats();
                
                // Retain modified vitals state cleanly
                combat.hp = charData.hp;
                combat.sp = charData.sp;
            }

            // CRITICAL FIX: Send all existing entities to the new player BEFORE adding them
            // This ensures the client sees Porings, drops, and other players already on the map
            for (const existingEntity of mapInstance.entities.values()) {
                const exMove = existingEntity.getComponent('movement');
                const exCombat = existingEntity.getComponent('combat');
                server.send(session, PacketIDs.ENTITY_SPAWN, {
                    entity_type: existingEntity.type,
                    id: existingEntity.id,
                    name: existingEntity.name || 'Unknown',
                    sprite: existingEntity.sprite || 'novice',
                    x: exMove ? exMove.x : 0,
                    y: exMove ? exMove.y : 0,
                    dir: exMove ? exMove.direction : 0,
                    speed: exMove ? exMove.speed : 200,
                    hp_percent: exCombat ? Math.floor((exCombat.hp / exCombat.maxHp) * 100) : 100
                });
            }

            // Bind player to the runtime space (triggers ENTITY_SPAWN to observers)
            mapInstance.addEntity(playerEntity, session);

            // Confirm entry connection initialization parameters
            server.send(session, PacketIDs.ENTER_MAP, {
                map_name: targetMapId,
                x: move ? move.x : 0,
                y: move ? move.y : 0
            });
        });
    }
}

module.exports = LoginHandler;