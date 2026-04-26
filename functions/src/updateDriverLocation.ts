import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

interface LocationUpdate {
  lat: number;
  lng: number;
  heading?: number;
  speed?: number;
  requestId?: string;
}

/**
 * HTTPS Callable — called by the driver app every 4 seconds while tracking is active.
 * Writes to location_updates/{driverId} (single document, updated in-place).
 * Also updates the driver's geohash for future radius queries.
 */
export const updateDriverLocation = functions
  .region("asia-south1")
  .https.onCall(async (data: LocationUpdate, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Must be authenticated"
      );
    }

    const driverId = context.auth.uid;
    const { lat, lng, heading, speed, requestId } = data;

    if (!lat || !lng) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "lat and lng are required"
      );
    }

    const geoPoint = new admin.firestore.GeoPoint(lat, lng);
    const geohash = encodeGeohash(lat, lng, 6);
    const timestamp = admin.firestore.FieldValue.serverTimestamp();

    const batch = db.batch();

    // Update live location document (watched by hospital app)
    batch.set(
      db.collection("location_updates").doc(driverId),
      {
        location: geoPoint,
        heading: heading ?? 0,
        speed: speed ?? 0,
        timestamp,
        requestId: requestId ?? null,
      },
      { merge: true }
    );

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
function encodeGeohash(lat: number, lng: number, precision: number): string {
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
      } else {
        idx = idx * 2;
        lngMax = lngMid;
      }
    } else {
      const latMid = (latMin + latMax) / 2;
      if (lat >= latMid) {
        idx = idx * 2 + 1;
        latMin = latMid;
      } else {
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
