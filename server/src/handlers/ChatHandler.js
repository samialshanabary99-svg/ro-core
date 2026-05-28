const { PacketIDs } = require('../../../shared/constants/packets');
const ChatSystem = require('../systems/ChatSystem');

/**
 * ChatHandler
 * Translates structural socket messages parameters into ambient context strings.
 */
class ChatHandler {
    /**
     * @param {Server} server 
     */
    static register(server) {
        
        // Handle Chat Message Payload (0x0093)
        server.registerHandler(PacketIDs.CHAT_MESSAGE, (session, payload) => {
            const mapInstance = session.activeMap;
            if (!mapInstance || !session.characterId) return;

            const playerEntity = mapInstance.entities.get(`char_${session.characterId}`);
            if (!playerEntity) return;

            const { scope, message } = payload;
            
            // Delegate chat payload context strings over system handlers
            ChatSystem.broadcastMessage(mapInstance, playerEntity.id, scope || 'say', message);
        });
    }
}

module.exports = ChatHandler;