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
exports.updateDriverLocation = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
/**
 * HTTPS Callable — called by the driver app every 4 seconds while tracking is active.
 * Writes to location_updates/{driverId} (single document, updated in-place).
 * Also updates the driver's geohash for future radius queries.
 */
exports.updateDriverLocation = functions
    .region("asia-south1")
    .https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Must be authenticated");
    }
    const driverId = context.auth.uid;
    const { lat, lng, heading, speed, requestId } = data;
    if (!lat || !lng) {
        throw new functions.https.HttpsError("invalid-argument", "lat and lng are required");
    }
    const geoPoint = new admin.firestore.GeoPoint(lat, lng);
    const geohash = encodeGeohash(lat, lng, 6);
    const timestamp = admin.firestore.FieldValue.serverTimestamp();
    const batch = db.batch();
    // Update live location document (watched by hospital app)
    batch.set(db.collection("location_updates").doc(driverId), {
        location: geoPoint,
        heading: heading !== null && heading !== void 0 ? heading : 0,
        speed: speed !== null && speed !== void 0 ? speed : 0,
        timestamp,
        requestId: requestId !== null && requestId !== void 0 ? requestId : null,
    }, { merge: true });
    // Update driver's geohash for future geo-queries
    batch.update(db.collection("drivers").doc(driverId), {
        location: geoPoint,
        geohash,
        lastLocationUpdate: timestamp,
    });
    await batch.commit();
    return { success: true };
});
/**
 * Simple geohash encoder (precision 6 ≈ 1.2km accuracy).
 * Mirrors the Dart implementation in location_service.dart.
 */
function encodeGeohash(lat, lng, precision) {
    const BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz";
    let idx = 0;
    let bit = 0;
    let evenBit = true;
    let geohash = "";
    let latMin = -90;
    let latMax = 90;
    let lngMin = -180;
    let lngMax = 180;
    while (geohash.length < precision) {
        if (evenBit) {
            const lngMid = (lngMin + lngMax) / 2;
            if (lng >= lngMid) {
                idx = idx * 2 + 1;
                lngMin = lngMid;
            }
            else {
                idx = idx * 2;
                lngMax = lngMid;
            }
        }
        else {
            const latMid = (latMin + latMax) / 2;
            if (lat >= latMid) {
                idx = idx * 2 + 1;
                latMin = latMid;
            }
            else {
                idx = idx * 2;
                latMax = latMid;
            }
        }
        evenBit = !evenBit;
        if (++bit === 5) {
            geohash += BASE32[idx];
            bit = 0;
            idx = 0;
        }
    }
    return geohash;
}
//# sourceMappingURL=updateDriverLocation.js.map