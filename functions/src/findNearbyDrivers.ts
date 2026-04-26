import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { geohashQueryBounds, distanceBetween } from "geofire-common";
import { enqueueDriverTimeout } from "./taskHelpers";

const db = admin.firestore();
const messaging = admin.messaging();

export interface NearbySearchParams {
  requestId: string;
  lat: number;
  lng: number;
  searchRadius: number;
  alreadyNotified: string[];
}

/**
 * Core logic: find nearby drivers, send FCM, enqueue timeout.
 * Exported for reuse by onDriverTimeout (radius expansion).
 */
export async function findNearbyDriversInternal(
  params: NearbySearchParams
): Promise<{ notified: number }> {
  const { requestId, lat, lng, searchRadius, alreadyNotified } = params;

  const bounds = geohashQueryBounds([lat, lng], searchRadius * 1000);
  const snapshots = await Promise.all(
    bounds.map((b) =>
      db.collection("drivers")
        .where("geohash", ">=", b[0])
        .where("geohash", "<=", b[1])
        .where("isOnline", "==", true)
        .where("isAvailable", "==", true)
        .get()
    )
  );

  const newDriverIds: string[] = [];
  const fcmTokens: string[] = [];

  for (const snap of snapshots) {
    for (const doc of snap.docs) {
      const driver = doc.data();
      const driverLat = (driver.location as admin.firestore.GeoPoint).latitude;
      const driverLng = (driver.location as admin.firestore.GeoPoint).longitude;
      const dist = distanceBetween([driverLat, driverLng], [lat, lng]);
      if (dist <= searchRadius && !alreadyNotified.includes(doc.id)) {
        newDriverIds.push(doc.id);
        if (driver.fcmToken) fcmTokens.push(driver.fcmToken as string);
      }
    }
  }

  if (newDriverIds.length > 0) {
    await db.collection("rescue_requests").doc(requestId).update({
      notifiedDriverIds: admin.firestore.FieldValue.arrayUnion(...newDriverIds),
    });

    if (fcmTokens.length > 0) {
      const chunks = chunkArray(fcmTokens, 500);
      await Promise.all(
        chunks.map((tokens) =>
          messaging.sendEachForMulticast({
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
          })
        )
      );
    }
  }

  // Enqueue 30-second timeout for radius expansion
  await enqueueDriverTimeout(requestId, searchRadius);

  return { notified: newDriverIds.length };
}

/**
 * HTTPS Callable — triggered when a new rescue request is created.
 */
export const findNearbyDrivers = functions
  .region("asia-south1")
  .https.onCall(async (data: NearbySearchParams) => {
    return findNearbyDriversInternal(data);
  });

function chunkArray<T>(arr: T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let i = 0; i < arr.length; i += size) {
    chunks.push(arr.slice(i, i + size));
  }
  return chunks;
}
