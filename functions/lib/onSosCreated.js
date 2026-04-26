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
exports.onSosCreated = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
const messaging = admin.messaging();
/**
 * Triggers whenever a new SOS request is written to /sos_requests.
 *
 * For now we broadcast the alert to **every verified online driver**
 * — drivers see distance in the alert card and decide whether to
 * accept.  Once we have enough density we can replace this with a
 * geohash-bounded query (see findNearbyDrivers.ts for reference).
 *
 * Sends BOTH a notification + data payload so:
 *   - Killed/background app: Android system tray shows the alert.
 *   - Foreground app: fcm_service.dart catches the data and shows a
 *     local high-priority notification.
 *
 * Tapping the notification routes the driver to /driver/sos/<sosId>.
 */
exports.onSosCreated = functions
    .region("asia-south1")
    .firestore.document("sos_requests/{sosId}")
    .onCreate(async (snap, context) => {
    const sosId = context.params.sosId;
    const sos = snap.data();
    // Only push for newly-pending SOS (skip if already assigned at create-time).
    if (sos.status !== "pending") {
        console.log(`SOS ${sosId} not pending — skipping push`);
        return null;
    }
    // Pull every verified, online driver.
    const driverSnap = await db
        .collection("drivers")
        .where("verificationStatus", "==", "verified")
        .where("isOnline", "==", true)
        .get();
    const tokens = [];
    driverSnap.forEach((doc) => {
        const t = doc.data().fcmToken;
        if (t && t.length > 0)
            tokens.push(t);
    });
    if (tokens.length === 0) {
        console.log(`SOS ${sosId} — no online drivers with FCM tokens.`);
        return null;
    }
    const phone = sos.phone || "";
    const patientName = sos.patientName || "";
    const emergencyType = sos.emergencyType || "";
    const lat = sos.latitude;
    const lng = sos.longitude;
    const titleBits = ["🚨 EMERGENCY SOS"];
    if (emergencyType)
        titleBits.push("·", emergencyType);
    const title = titleBits.join(" ");
    const bodyBits = [];
    if (patientName)
        bodyBits.push(patientName);
    if (phone)
        bodyBits.push(phone);
    bodyBits.push(`Location: ${Number(lat).toFixed(4)}, ${Number(lng).toFixed(4)}`);
    const body = bodyBits.join(" · ");
    // Send in chunks of 500 (FCM multicast limit).
    const chunks = chunk(tokens, 500);
    let success = 0;
    let failed = 0;
    await Promise.all(chunks.map(async (slice) => {
        const resp = await messaging.sendEachForMulticast({
            tokens: slice,
            notification: { title, body },
            data: {
                type: "sos",
                id: sosId,
                phone,
                patientName,
                emergencyType,
                latitude: String(lat),
                longitude: String(lng),
            },
            android: {
                priority: "high",
                notification: {
                    channelId: "sos_emergency",
                    sound: "default",
                    priority: "max",
                    defaultVibrateTimings: true,
                    defaultLightSettings: true,
                    color: "#FF3B3B",
                    tag: `sos-${sosId}`,
                },
            },
            apns: {
                headers: { "apns-priority": "10" },
                payload: {
                    aps: {
                        sound: "default",
                        badge: 1,
                        category: "sos",
                        "content-available": 1,
                    },
                },
            },
        });
        success += resp.successCount;
        failed += resp.failureCount;
        // Cleanup: remove invalid tokens from the drivers collection.
        const deadIndexes = [];
        resp.responses.forEach((r, i) => {
            var _a;
            if (!r.success) {
                const code = ((_a = r.error) === null || _a === void 0 ? void 0 : _a.code) || "";
                if (code === "messaging/invalid-registration-token" ||
                    code === "messaging/registration-token-not-registered") {
                    deadIndexes.push(i);
                }
            }
        });
        if (deadIndexes.length > 0) {
            const deadTokens = deadIndexes.map((i) => slice[i]);
            await purgeDeadTokens(deadTokens);
        }
    }));
    console.log(`SOS ${sosId} pushed → ${success} delivered, ${failed} failed, ${tokens.length} drivers attempted`);
    return { success, failed, attempted: tokens.length };
});
async function purgeDeadTokens(deadTokens) {
    const drvSnap = await db
        .collection("drivers")
        .where("fcmToken", "in", deadTokens.slice(0, 10))
        .get();
    const batch = db.batch();
    drvSnap.forEach((doc) => {
        batch.update(doc.ref, { fcmToken: admin.firestore.FieldValue.delete() });
    });
    if (!drvSnap.empty)
        await batch.commit();
}
function chunk(arr, size) {
    const out = [];
    for (let i = 0; i < arr.length; i += size)
        out.push(arr.slice(i, i + size));
    return out;
}
//# sourceMappingURL=onSosCreated.js.map