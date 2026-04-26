import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { findNearbyHospitalsInternal } from "./findNearbyHospitals";

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Firestore onUpdate trigger — fires when a rescue_request document is updated.
 * Detects the moment assignedDriverId is set (driver accepted).
 * 1. Sends FCM cancellation to all other notified drivers
 * 2. Kicks off hospital search from the patient's location
 */
export const onDriverAccept = functions
  .region("asia-south1")
  .firestore.document("rescue_requests/{requestId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const { requestId } = context.params;

    // Trigger only when assignedDriverId is newly set
    const driverJustAssigned =
      !before.assignedDriverId && after.assignedDriverId;

    if (!driverJustAssigned) return;

    // Cancel FCM for all other notified drivers (excluding the winner)
    const notifiedDriverIds = (after.notifiedDriverIds as string[]) || [];
    const assignedDriverId = after.assignedDriverId as string;
    const cancelTargets = notifiedDriverIds.filter((id) => id !== assignedDriverId);

    if (cancelTargets.length > 0) {
      const tokenSnaps = await Promise.all(
        cancelTargets.map((id) => db.collection("drivers").doc(id).get())
      );
      const cancelTokens = tokenSnaps
        .map((s) => s.data()?.fcmToken as string | undefined)
        .filter((t): t is string => !!t);

      if (cancelTokens.length > 0) {
        const chunks = chunkArray(cancelTokens, 500);
        await Promise.all(
          chunks.map((tokens) =>
            messaging.sendEachForMulticast({
              tokens,
              data: { type: "request_cancelled", requestId },
              android: { priority: "high" },
            })
          )
        );
      }
    }

    // Start hospital search from patient's location
    const patientLat = (after.patientLocation as admin.firestore.GeoPoint).latitude;
    const patientLng = (after.patientLocation as admin.firestore.GeoPoint).longitude;

    await db.collection("rescue_requests").doc(requestId).update({
      status: "pending_hospital",
      currentHospitalSearchRadius: 1,
      notifiedHospitalIds: [],
    });

    await findNearbyHospitalsInternal({
      requestId,
      lat: patientLat,
      lng: patientLng,
      searchRadius: 1,
      alreadyNotified: [],
    });
  });

function chunkArray<T>(arr: T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let i = 0; i < arr.length; i += size) {
    chunks.push(arr.slice(i, i + size));
  }
  return chunks;
}
