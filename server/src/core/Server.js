const WebSocket = require('ws');
const crypto = require('crypto');
const PacketFactory = require('./PacketFactory');
const { PacketDirection } = require('../../../shared/constants/packets');

/**
 * Core WebSocket Bootstrap Network Provider Engine.
 * Manages connected network client interfaces, safety sessions, and routes buffers.
 */
class Server {
    constructor(config) {
        this.port = config.server.port;
        this.host = config.server.host;
        this.wss = null;
        this.clients = new Map(); // Maps ws instance -> Session Object metadata
        this.packetHandlers = new Map(); // Maps PID -> System Event handler function
    }

    /**
     * Establishes network socket server loop hooks.
     */
    start() {
        this.wss = new WebSocket.Server({ port: this.port, host: this.host });

        this.wss.on('connection', (ws) => this.handleConnection(ws));
        this.wss.on('error', (error) => console.error('[Network] Server Error:', error));

        console.log(`[Network] Application Socket Server running clean on: ws://${this.host}:${this.port}`);
    }

    /**
     * Registers a structural handler connection path mapping logic directly.
     * @param {string} pid 
     * @param {function} handler 
     */
    registerHandler(pid, handler) {
        this.packetHandlers.set(pid, handler);
    }

    /**
     * Mounts connection hooks and configures listeners cleanly.
     */
    handleConnection(ws) {
        const sessionToken = crypto.randomBytes(16).toString('hex');
        
        const session = {
            token: sessionToken,
            accountId: null,
            characterId: null,
            activeMap: null,
            ws: ws
        };

        this.clients.set(ws, session);

        ws.on('message', (message) => this.handleMessage(ws, message));
        ws.on('close', () => this.handleDisconnect(ws));
        ws.on('error', (err) => console.error(`[Network] Session error tracker [${sessionToken}]:`, err.message));
    }

    /**
     * Dispatches socket packet parsing actions to operational pipeline loops.
     */
    handleMessage(ws, message) {
        const session = this.clients.get(ws);
        if (!session) return;

        const packet = PacketFactory.decode(message);
        if (!packet) return;

        const handler = this.packetHandlers.get(packet.pid);
        if (handler) {
            const dir = PacketDirection[packet.pid] || '??';
            console.log(`[Network] [${dir}] Handling packet ${packet.pid} for Session: ${session.token}`);
            
            try {
                handler(session, packet.payload);
            } catch (err) {
                console.error(`[Network] Handler execution crashed under payload processing for ${packet.pid}:`, err.stack);
            }
        } else {
            console.warn(`[Network] Operational route lacking implementation logic for PID: ${packet.pid}`);
        }
    }

    /**
     * Tears down active references safely to mitigate leakage vectors.
     */
    handleDisconnect(ws) {
        const session = this.clients.get(ws);
        if (session) {
            console.log(`[Network] Client context tearing down session instance ID: ${session.token}`);
            session.ws = null;
            this.clients.delete(ws);
        }
    }

    /**
     * Delivers safely constructed payloads directly to singular active socket targets.
     * @param {Object} session 
     * @param {string} pid 
     * @param {Object} payload 
     */
    send(session, pid, payload = {}) {
        if (!session || !session.ws || session.ws.readyState !== WebSocket.OPEN) {
            return;
        }

        try {
            const rawData = PacketFactory.encode(pid, payload);
            session.ws.send(rawData);
        } catch (error) {
            console.error(`[Network] Serialization delivery failure targeting session ${session.token}:`, error.message);
        }
    }

    /**
     * Broadcasts a serialized packet string once to multiple targeted sessions simultaneously.
     * @param {Object[]} sessions - Array of active session state targets
     * @param {string} pid - Hex-string message code identifier
     * @param {Object} payload - Associated contextual variables
     */
    broadcast(sessions, pid, payload = {}) {
        try {
            const rawData = PacketFactory.encode(pid, payload);
            for (const session of sessions) {
                if (session && session.ws && session.ws.readyState === WebSocket.OPEN) {
                    session.ws.send(rawData);
                }
            }
        } catch (error) {
            console.error('[Network] Broadcast serialization failure:', error.message);
        }
    }

    /**
     * Tears down base engine bindings systematically.
     */
    shutdown() {
        console.log('[Network] System socket execution interfaces halting processes...');
        if (this.wss) {
            this.wss.close();
        }
    }
}

module.exports = Server;