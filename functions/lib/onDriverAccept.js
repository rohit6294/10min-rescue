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
exports.onDriverAccept = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const findNearbyHospitals_1 = require("./findNearbyHospitals");
const db = admin.firestore();
const messaging = admin.messaging();
/**
 * Firestore onUpdate trigger — fires when a rescue_request document is updated.
 * Detects the moment assignedDriverId is set (driver accepted).
 * 1. Sends FCM cancellation to all other notified drivers
 * 2. Kicks off hospital search from the patient's location
 */
exports.onDriverAccept = functions
    .region("asia-south1")
    .firestore.document("rescue_requests/{requestId}")
    .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const { requestId } = context.params;
    // Trigger only when assignedDriverId is newly set
    const driverJustAssigned = !before.assignedDriverId && after.assignedDriverId;
    if (!driverJustAssigned)
        return;
    // Cancel FCM for all other notified drivers (excluding the winner)
    const notifiedDriverIds = after.notifiedDriverIds || [];
    const assignedDriverId = after.assignedDriverId;
    const cancelTargets = notifiedDriverIds.filter((id) => id !== assignedDriverId);
    if (cancelTargets.length > 0) {
        const tokenSnaps = await Promise.all(cancelTargets.map((id) => db.collection("drivers").doc(id).get()));
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
    // Start hospital search from patient's location
    const patientLat = after.patientLocation.latitude;
    const patientLng = after.patientLocation.longitude;
    await db.collection("rescue_requests").doc(requestId).update({
        status: "pending_hospital",
        currentHospitalSearchRadius: 1,
        notifiedHospitalIds: [],
    });
    await (0, findNearbyHospitals_1.findNearbyHospitalsInternal)({
        requestId,
        lat: patientLat,
        lng: patientLng,
        searchRadius: 1,
        alreadyNotified: [],
    });
});
function chunkArray(arr, size) {
    const chunks = [];
    for (let i = 0; i < arr.length; i += size) {
        chunks.push(arr.slice(i, i + size));
    }
    return chunks;
}
//# sourceMappingURL=onDriverAccept.js.map