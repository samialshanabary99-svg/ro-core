const DatabaseConnection = require('better-sqlite3');
const path = require('path');

/**
 * Authoritative SQLite Storage Driver Interface Wrapper
 */
class Database {
    constructor(config) {
        this.config = config;
        this.db = null;
        this.statements = {};
    }

    init() {
        const dbPath = path.resolve(this.config.database.storagePath);
        this.db = new DatabaseConnection(dbPath);
        
        // Optimize performance parameters via WAL flags
        this.db.pragma('journal_mode = WAL');
        this.db.pragma('synchronous = NORMAL');

        this.createTables();
        this.prepareStatements();
        console.log('[Database] Storage Engine Initialization Complete.');
    }

    createTables() {
        // Accounts Schema
        this.db.prepare(`
            CREATE TABLE IF NOT EXISTS accounts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT UNIQUE NOT NULL,
                password_hash TEXT NOT NULL,
                created_at INTEGER NOT NULL
            )
        `).run();

        // Characters Schema
        this.db.prepare(`
            CREATE TABLE IF NOT EXISTS characters (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                account_id INTEGER NOT NULL,
                name TEXT UNIQUE NOT NULL,
                job_id INTEGER DEFAULT 0,
                base_level INTEGER DEFAULT 1,
                job_level INTEGER DEFAULT 1,
                base_exp INTEGER DEFAULT 0,
                job_exp INTEGER DEFAULT 0,
                hp INTEGER DEFAULT 40,
                max_hp INTEGER DEFAULT 40,
                sp INTEGER DEFAULT 11,
                max_sp INTEGER DEFAULT 11,
                str INTEGER DEFAULT 1,
                agi INTEGER DEFAULT 1,
                vit INTEGER DEFAULT 1,
                int INTEGER DEFAULT 1,
                dex INTEGER DEFAULT 1,
                luk INTEGER DEFAULT 1,
                stat_points INTEGER DEFAULT 0,
                map_name TEXT DEFAULT 'prt_fild01',
                x INTEGER DEFAULT 50,
                y INTEGER DEFAULT 50,
                FOREIGN KEY(account_id) REFERENCES accounts(id)
            )
        `).run();
    }

    prepareStatements() {
        this.statements.createAccount = this.db.prepare(
            'INSERT INTO accounts (username, password_hash, created_at) VALUES (?, ?, ?)'
        );
        this.statements.getAccountByUsername = this.db.prepare(
            'SELECT * FROM accounts WHERE username = ?'
        );
        this.statements.getCharactersByAccount = this.db.prepare(
            'SELECT * FROM characters WHERE account_id = ?'
        );
        this.statements.getCharacterById = this.db.prepare(
            'SELECT * FROM characters WHERE id = ?'
        );
        this.statements.saveCharacterStats = this.db.prepare(`
            UPDATE characters SET 
                base_level = ?, job_level = ?, base_exp = ?, job_exp = ?,
                hp = ?, max_hp = ?, sp = ?, max_sp = ?,
                str = ?, agi = ?, vit = ?, int = ?, dex = ?, luk = ?,
                stat_points = ?, map_name = ?, x = ?, y = ?
            WHERE id = ?
        `);
    }

    close() {
        if (this.db) {
            this.db.close();
            console.log('[Database] Storage Connections Terminated.');
        }
    }
}

module.exports = Database;