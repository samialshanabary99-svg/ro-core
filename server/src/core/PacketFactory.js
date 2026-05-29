const { PacketIDs, PacketNames } = require('../../../shared/constants/packets');

/**
 * Centralized packet conversion layer.
 */
class PacketFactory {
    static decode(rawData) {
        try {
            const dataString = typeof rawData === 'string' ? rawData : rawData.toString();
            const json = JSON.parse(dataString);

            if (!json || typeof json.pid !== 'string') {
                console.warn('[PacketFactory] Frame discarded: Missing Packet ID.');
                return null;
            }

            if (!PacketNames[json.pid]) {
                console.warn(`[PacketFactory] Unknown packet ID: ${json.pid}`);
                return null;
            }

            return {
                pid: json.pid,
                payload: json.payload || {}
            };
        } catch (error) {
            console.error('[PacketFactory] Decode error:', error.message);
            return null;
        }
    }

    static encode(pid, payload = {}) {
        if (!PacketNames[pid]) {
            throw new Error(`[PacketFactory] Unknown PID: ${pid}`);
        }

        return JSON.stringify({
            pid: pid,
            payload: payload
        });
    }
}

module.exports = PacketFactory;