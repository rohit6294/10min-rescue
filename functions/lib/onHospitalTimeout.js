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
exports.onHospitalTimeout = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const findNearbyHospitals_1 = require("./findNearbyHospitals");
const db = admin.firestore();
/**
 * Cloud Tasks HTTP endpoint — fires 30s after findNearbyHospitals.
 * If no hospital accepted, expand radius by +1km and search again.
 */
exports.onHospitalTimeout = functions
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
    // Skip if hospital already assigned
    if (request.assignedHospitalId ||
        (request.status !== "pending_hospital" &&
            request.status !== "driver_assigned")) {
        res.status(200).send("Already handled");
        return;
    }
    const newRadius = currentRadius + 1;
    const MAX_RADIUS = 20; // Hospitals can be further than drivers
    if (newRadius > MAX_RADIUS) {
        // Mark as critical — no hospital found, driver continues to nearest anyway
        await requestRef.update({
            hospitalSearchStatus: "no_hospital_found",
        });
        res.status(200).send("No hospital found within max radius");
        return;
    }
    await requestRef.update({ currentHospitalSearchRadius: newRadius });
    const patientLat = request.patientLocation.latitude;
    const patientLng = request.patientLocation.longitude;
    const alreadyNotified = request.notifiedHospitalIds || [];
    await (0, findNearbyHospitals_1.findNearbyHospitalsInternal)({
        requestId,
        lat: patientLat,
        lng: patientLng,
        searchRadius: newRadius,
        alreadyNotified,
    });
    res.status(200).send(`Hospital radius expanded to ${newRadius}km`);
});
//# sourceMappingURL=onHospitalTimeout.js.map