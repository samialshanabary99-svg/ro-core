const { PacketIDs } = require('../../../shared/constants/packets');

/**
 * ChatSystem
 * Manages spatial text messages communications across unified target arrays.
 */
class ChatSystem {
    static broadcastMessage(mapInstance, senderId, scope, message) {
        if (!message || message.trim().length === 0) return;

        const sanitizedMsg = message.substring(0, 150);

        mapInstance.server.broadcast(Array.from(mapInstance.sessions.values()), PacketIDs.CHAT_MESSAGE, {
            scope: scope,
            message: sanitizedMsg,
            sender_id: senderId
        });
    }
}

module.exports = ChatSystem;