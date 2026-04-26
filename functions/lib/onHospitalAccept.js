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
exports.onHospitalAccept = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
const messaging = admin.messaging();
/**
 * Firestore onUpdate trigger — fires when a rescue_request document is updated.
 * Detects the moment assignedHospitalId is set (hospital accepted).
 * 1. Sends FCM cancellation to all other notified hospitals
 * 2. Updates assigned driver's currentRequestId with hospital info
 * 3. Marks request status as hospital_assigned
 */
exports.onHospitalAccept = functions
    .region("asia-south1")
    .firestore.document("rescue_requests/{requestId}")
    .onUpdate(async (change, context) => {
    var _a, _b, _c, _d, _e, _f;
    const before = change.before.data();
    const after = change.after.data();
    const { requestId } = context.params;
    // Trigger only when assignedHospitalId is newly set
    const hospitalJustAssigned = !before.assignedHospitalId && after.assignedHospitalId;
    if (!hospitalJustAssigned)
        return;
    const assignedHospitalId = after.assignedHospitalId;
    const notifiedHospitalIds = after.notifiedHospitalIds || [];
    const cancelTargets = notifiedHospitalIds.filter((id) => id !== assignedHospitalId);
    // Cancel FCM for other hospitals
    if (cancelTargets.length > 0) {
        const tokenSnaps = await Promise.all(cancelTargets.map((id) => db.collection("hospitals").doc(id).get()));
        const cancelTokens = tokenSnaps
            .map((s) => { var _a; return (_a = s.data()) === null || _a === void 0 ? void 0 : _a.fcmToken; })
            .filter((t) => !!t);
        if (cancelTokens.length > 0) {
            const chunks = chunkArray(cancelTokens, 500);
            await Promise.all(chunks.map((tokens) => messaging.sendEachForMulticast({
                tokens,
                data: { type: "request_cancelled", requestId },
                android: { priority: "high" },
            })));
        }
    }
    // Load hospital details to embed in request
    const hospitalSnap = await db
        .collection("hospitals")
        .doc(assignedHospitalId)
        .get();
    const hospital = hospitalSnap.data();
    await db.collection("rescue_requests").doc(requestId).update({
        status: "hospital_assigned",
        hospitalAcceptedAt: admin.firestore.FieldValue.serverTimestamp(),
        hospitalName: (_a = hospital === null || hospital === void 0 ? void 0 : hospital.name) !== null && _a !== void 0 ? _a : "",
        hospitalAddress: (_b = hospital === null || hospital === void 0 ? void 0 : hospital.address) !== null && _b !== void 0 ? _b : "",
        hospitalLocation: (_c = hospital === null || hospital === void 0 ? void 0 : hospital.location) !== null && _c !== void 0 ? _c : null,
    });
    // Notify the assigned driver about which hospital was selected
    const assignedDriverId = after.assignedDriverId;
    if (assignedDriverId) {
        const driverSnap = await db.collection("drivers").doc(assignedDriverId).get();
        const driverToken = (_d = driverSnap.data()) === null || _d === void 0 ? void 0 : _d.fcmToken;
        if (driverToken) {
            await messaging.send({
                token: driverToken,
                data: {
                    type: "hospital_assigned",
                    requestId,
                    hospitalName: (_e = hospital === null || hospital === void 0 ? void 0 : hospital.name) !== null && _e !== void 0 ? _e : "",
                    hospitalAddress: (_f = hospital === null || hospital === void 0 ? void 0 : hospital.address) !== null && _f !== void 0 ? _f : "",
                },
                android: { priority: "high" },
            });
        }
    }
});
function chunkArray(arr, size) {
    const chunks = [];
    for (let i = 0; i < arr.length; i += size) {
        chunks.push(arr.slice(i, i + size));
    }
    return chunks;
}
//# sourceMappingURL=onHospitalAccept.js.map