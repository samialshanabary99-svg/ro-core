/**
 * MockDatabase
 * Zero-compilation in-memory database for Windows testing.
 * Identical API to Database.js.
 */
class MockDatabase {
    constructor() {
        this.accounts = new Map();
        this.characters = new Map();
        this.inventory = new Map();
        this.nextAccountId = 1;
        this.nextCharId = 1;
        this.statements = {};
    }

    init() {
        this.prepareStatements();
        console.log('[MockDatabase] In-memory store initialized.');
    }

    prepareStatements() {
        const self = this;

        this.statements.createAccount = {
            run(username, passwordHash, createdAt) {
                const id = self.nextAccountId++;
                const account = { id, username, password_hash: passwordHash, created_at: createdAt };
                self.accounts.set(id, account);
                return { lastInsertRowid: id };
            }
        };

        this.statements.getAccountByUsername = {
            get(username) {
                for (const acc of self.accounts.values()) {
                    if (acc.username === username) return acc;
                }
                return undefined;
            }
        };

        this.statements.getCharactersByAccount = {
            all(accountId) {
                const results = [];
                for (const char of self.characters.values()) {
                    if (char.account_id === accountId) results.push(char);
                }
                return results;
            }
        };

        this.statements.createCharacter = {
            run(accountId, name, savedAt) {
                const id = self.nextCharId++;
                const char = {
                    id, account_id: accountId, name, job_id: 0,
                    base_level: 1, job_level: 1, base_exp: 0, job_exp: 0,
                    hp: 47, sp: 15, max_hp: 47, max_sp: 15,
                    str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1,
                    stat_points: 0, map_name: 'prt_fild01', x: 30, y: 30,
                    saved_at: savedAt
                };
                self.characters.set(id, char);
                return { lastInsertRowid: id };
            }
        };

        this.statements.getCharacterById = {
            get(charId) {
                return self.characters.get(charId);
            }
        };

        this.statements.saveCharacter = {
            run(jobId, baseLevel, jobLevel, baseExp, jobExp, hp, sp, maxHp, maxSp,
                str, agi, vit, int, dex, luk, statPoints, mapName, x, y, savedAt, charId) {
                const char = self.characters.get(charId);
                if (!char) return;
                Object.assign(char, {
                    job_id: jobId, base_level: baseLevel, job_level: jobLevel,
                    base_exp: baseExp, job_exp: jobExp, hp, sp,
                    max_hp: maxHp, max_sp: maxSp, str, agi, vit, int, dex, luk,
                    stat_points: statPoints, map_name: mapName, x, y, saved_at: savedAt
                });
            }
        };

        this.statements.getInventoryByChar = {
            all(charId) {
                return self.inventory.get(charId) || [];
            }
        };

        this.statements.upsertInventoryItem = {
            run(charId, itemId, amount, equipLoc) {
                const items = self.inventory.get(charId) || [];
                const existing = items.find(i => i.item_id === itemId);
                if (existing) existing.amount += amount;
                else items.push({ id: items.length + 1, char_id: charId, item_id: itemId, amount, equip_loc: equipLoc });
                self.inventory.set(charId, items);
            }
        };
    }

    transaction(operations) {
        return operations();
    }

    close() {
        this.accounts.clear();
        this.characters.clear();
        this.inventory.clear();
        console.log('[MockDatabase] Memory cleared.');
    }
}

module.exports = MockDatabase;