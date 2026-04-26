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
exports.findNearbyHospitals = void 0;
exports.findNearbyHospitalsInternal = findNearbyHospitalsInternal;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const geofire_common_1 = require("geofire-common");
const taskHelpers_1 = require("./taskHelpers");
const db = admin.firestore();
const messaging = admin.messaging();
/**
 * Core logic: find nearby active hospitals, send FCM, enqueue timeout.
 * Exported for reuse by onHospitalTimeout (radius expansion).
 */
async function findNearbyHospitalsInternal(params) {
    const { requestId, lat, lng, searchRadius, alreadyNotified } = params;
    const bounds = (0, geofire_common_1.geohashQueryBounds)([lat, lng], searchRadius * 1000);
    const snapshots = await Promise.all(bounds.map((b) => db.collection("hospitals")
        .where("geohash", ">=", b[0])
        .where("geohash", "<=", b[1])
        .where("isActive", "==", true)
        .get()));
    const newHospitalIds = [];
    const fcmTokens = [];
    for (const snap of snapshots) {
        for (const doc of snap.docs) {
            const hospital = doc.data();
            const hLat = hospital.location.latitude;
            const hLng = hospital.location.longitude;
            const dist = (0, geofire_common_1.distanceBetween)([hLat, hLng], [lat, lng]);
            if (dist <= searchRadius && !alreadyNotified.includes(doc.id)) {
                newHospitalIds.push(doc.id);
                if (hospital.fcmToken)
                    fcmTokens.push(hospital.fcmToken);
            }
        }
    }
    if (newHospitalIds.length > 0) {
        await db.collection("rescue_requests").doc(requestId).update({
            notifiedHospitalIds: admin.firestore.FieldValue.arrayUnion(...newHospitalIds),
        });
        if (fcmTokens.length > 0) {
            const chunks = chunkArray(fcmTokens, 500);
            await Promise.all(chunks.map((tokens) => messaging.sendEachForMulticast({
                tokens,
                data: { type: "incoming_ambulance", requestId },
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
    await (0, taskHelpers_1.enqueueHospitalTimeout)(requestId, searchRadius);
    return { notified: newHospitalIds.length };
}
/**
 * HTTPS Callable — called by onDriverAccept after a driver is assigned.
 */
exports.findNearbyHospitals = functions
    .region("asia-south1")
    .https.onCall(async (data) => {
    return findNearbyHospitalsInternal(data);
});
function chunkArray(arr, size) {
    const chunks = [];
    for (let i = 0; i < arr.length; i += size) {
        chunks.push(arr.slice(i, i + size));
    }
    return chunks;
}
//# sourceMappingURL=findNearbyHospitals.js.map