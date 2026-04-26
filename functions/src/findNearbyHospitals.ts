import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { geohashQueryBounds, distanceBetween } from "geofire-common";
import { enqueueHospitalTimeout } from "./taskHelpers";

const db = admin.firestore();
const messaging = admin.messaging();

export interface NearbyHospitalParams {
  requestId: string;
  lat: number;
  lng: number;
  searchRadius: number;
  alreadyNotified: string[];
}

/**
 * Core logic: find nearby active hospitals, send FCM, enqueue timeout.
 * Exported for reuse by onHospitalTimeout (radius expansion).
 */
export async function findNearbyHospitalsInternal(
  params: NearbyHospitalParams
): Promise<{ notified: number }> {
  const { requestId, lat, lng, searchRadius, alreadyNotified } = params;

  const bounds = geohashQueryBounds([lat, lng], searchRadius * 1000);
  const snapshots = await Promise.all(
    bounds.map((b) =>
      db.collection("hospitals")
        .where("geohash", ">=", b[0])
        .where("geohash", "<=", b[1])
        .where("isActive", "==", true)
        .get()
    )
  );

  const newHospitalIds: string[] = [];
  const fcmTokens: string[] = [];

  for (const snap of snapshots) {
    for (const doc of snap.docs) {
      const hospital = doc.data();
      const hLat = (hospital.location as admin.firestore.GeoPoint).latitude;
      const hLng = (hospital.location as admin.firestore.GeoPoint).longitude;
      const dist = distanceBetween([hLat, hLng], [lat, lng]);
      if (dist <= searchRadius && !alreadyNotified.includes(doc.id)) {
        newHospitalIds.push(doc.id);
        if (hospital.fcmToken) fcmTokens.push(hospital.fcmToken as string);
      }
    }
  }

  if (newHospitalIds.length > 0) {
    await db.collection("rescue_requests").doc(requestId).update({
      notifiedHospitalIds: admin.firestore.FieldValue.arrayUnion(...newHospitalIds),
    });

    if (fcmTokens.length > 0) {
      const chunks = chunkArray(fcmTokens, 500);
      await Promise.all(
        chunks.map((tokens) =>
          messaging.sendEachForMulticast({
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
          })
        )
      );
    }
  }

  await enqueueHospitalTimeout(requestId, searchRadius);

  return { notified: newHospitalIds.length };
}

/**
 * HTTPS Callable — called by onDriverAccept after a driver is assigned.
 */
export const findNearbyHospitals = functions
  .region("asia-south1")
  .https.onCall(async (data: NearbyHospitalParams) => {
    return findNearbyHospitalsInternal(data);
  });

function chunkArray<T>(arr: T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let i = 0; i < arr.length; i += size) {
    chunks.push(arr.slice(i, i + size));
  }
  return chunks;
}
