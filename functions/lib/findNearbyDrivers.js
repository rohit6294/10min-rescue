"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.findNearbyDrivers = void 0;
exports.findNearbyDriversInternal = findNearbyDriversInternal;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const geofire_common_1 = require("geofire-common");
const taskHelpers_1 = require("./taskHelpers");
const db = admin.firestore();
const messaging = admin.messaging();
/**
 * Core logic: find nearby drivers, send FCM, enqueue timeout.
 * Exported for reuse by onDriverTimeout (radius expansion).
 */
async function findNearbyDriversInternal(params) {
    const { requestId, lat, lng, searchRadius, alreadyNotified } = params;
    const bounds = (0, geofire_common_1.geohashQueryBounds)([lat, lng], searchRadius * 1000);
    const snapshots = await Promise.all(bounds.map((b) => db.collection("drivers")
        .where("geohash", ">=", b[0])
        .where("geohash", "<=", b[1])
        .where("isOnline", "==", true)
        .where("isAvailable", "==", true)
        .get()));
    const newDriverIds = [];
    const fcmTokens = [];
    for (const snap of snapshots) {
        for (const doc of snap.docs) {
            const driver = doc.data();
            const driverLat = driver.location.latitude;
            const driverLng = driver.location.longitude;
            const dist = (0, geofire_common_1.distanceBetween)([driverLat, driverLng], [lat, lng]);
            if (dist <= searchRadius && !alreadyNotified.includes(doc.id)) {
                newDriverIds.push(doc.id);
                if (driver.fcmToken)
                    fcmTokens.push(driver.fcmToken);
            }
        }
    }
    if (newDriverIds.length > 0) {
        await db.collection("rescue_requests").doc(requestId).update({
            notifiedDriverIds: admin.firestore.FieldValue.arrayUnion(...newDriverIds),
        });
        if (fcmTokens.length > 0) {
            const chunks = chunkArray(fcmTokens, 500);
            await Promise.all(chunks.map((tokens) => messaging.sendEachForMulticast({
                tokens,
                data: { type: "incoming_request", requestId },
                android: {
                    priority: "high",
                    notification: {
                        channelId: "emergency_requests",
                        sound: "default",
                        priority: "max",
                    },
                },
            })));
        }
    }
    // Enqueue 30-second timeout for radius expansion
    await (0, taskHelpers_1.enqueueDriverTimeout)(requestId, searchRadius);
    return { notified: newDriverIds.length };
}
/**
 * HTTPS Callable — triggered when a new rescue request is created.
 */
exports.findNearbyDrivers = functions
    .region("asia-south1")
    .https.onCall(async (data) => {
    return findNearbyDriversInternal(data);
});
function chunkArray(arr, size) {
    const chunks = [];
    for (let i = 0; i < arr.length; i += size) {
        chunks.push(arr.slice(i, i + size));
    }
    return chunks;
}
//# sourceMappingURL=findNearbyDrivers.js.map