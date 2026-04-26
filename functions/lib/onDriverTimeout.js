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
exports.onDriverTimeout = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const findNearbyDrivers_1 = require("./findNearbyDrivers");
const db = admin.firestore();
/**
 * Cloud Tasks HTTP endpoint — fires 30s after findNearbyDrivers.
 * If no driver accepted, expand radius by +1km and search again.
 */
exports.onDriverTimeout = functions
    .region("asia-south1")
    .https.onRequest(async (req, res) => {
    const { requestId, currentRadius } = req.body;
    const requestRef = db.collection("rescue_requests").doc(requestId);
    const requestSnap = await requestRef.get();
    if (!requestSnap.exists) {
        res.status(200).send("Request not found");
        return;
    }
    const request = requestSnap.data();
    // Skip if driver already assigned or request is no longer pending
    if (request.assignedDriverId || request.status !== "pending_driver") {
        res.status(200).send("Already handled");
        return;
    }
    const newRadius = currentRadius + 1;
    const MAX_RADIUS = 10;
    if (newRadius > MAX_RADIUS) {
        await requestRef.update({
            status: "cancelled",
            cancelReason: "no_driver_available",
        });
        res.status(200).send("No driver found within max radius, cancelled");
        return;
    }
    await requestRef.update({ currentDriverSearchRadius: newRadius });
    const patientLat = request.patientLocation.latitude;
    const patientLng = request.patientLocation.longitude;
    const alreadyNotified = request.notifiedDriverIds || [];
    await (0, findNearbyDrivers_1.findNearbyDriversInternal)({
        requestId,
        lat: patientLat,
        lng: patientLng,
        searchRadius: newRadius,
        alreadyNotified,
    });
    res.status(200).send(`Radius expanded to ${newRadius}km`);
});
//# sourceMappingURL=onDriverTimeout.js.map