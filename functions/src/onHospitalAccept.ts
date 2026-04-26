import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Firestore onUpdate trigger — fires when a rescue_request document is updated.
 * Detects the moment assignedHospitalId is set (hospital accepted).
 * 1. Sends FCM cancellation to all other notified hospitals
 * 2. Updates assigned driver's currentRequestId with hospital info
 * 3. Marks request status as hospital_assigned
 */
export const onHospitalAccept = functions
  .region("asia-south1")
  .firestore.document("rescue_requests/{requestId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const { requestId } = context.params;

    // Trigger only when assignedHospitalId is newly set
    const hospitalJustAssigned =
      !before.assignedHospitalId && after.assignedHospitalId;

    if (!hospitalJustAssigned) return;

    const assignedHospitalId = after.assignedHospitalId as string;
    const notifiedHospitalIds = (after.notifiedHospitalIds as string[]) || [];
    const cancelTargets = notifiedHospitalIds.filter(
      (id) => id !== assignedHospitalId
    );

    // Cancel FCM for other hospitals
    if (cancelTargets.length > 0) {
      const tokenSnaps = await Promise.all(
        cancelTargets.map((id) => db.collection("hospitals").doc(id).get())
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

    // Load hospital details to embed in request
    const hospitalSnap = await db
      .collection("hospitals")
      .doc(assignedHospitalId)
      .get();
    const hospital = hospitalSnap.data();

    await db.collection("rescue_requests").doc(requestId).update({
      status: "hospital_assigned",
      hospitalAcceptedAt: admin.firestore.FieldValue.serverTimestamp(),
      hospitalName: hospital?.name ?? "",
      hospitalAddress: hospital?.address ?? "",
      hospitalLocation: hospital?.location ?? null,
    });

    // Notify the assigned driver about which hospital was selected
    const assignedDriverId = after.assignedDriverId as string | undefined;
    if (assignedDriverId) {
      const driverSnap = await db.collection("drivers").doc(assignedDriverId).get();
      const driverToken = driverSnap.data()?.fcmToken as string | undefined;
      if (driverToken) {
        await messaging.send({
          token: driverToken,
          data: {
            type: "hospital_assigned",
            requestId,
            hospitalName: hospital?.name ?? "",
            hospitalAddress: hospital?.address ?? "",
          },
          android: { priority: "high" },
        });
      }
    }
  });

function chunkArray<T>(arr: T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let i = 0; i < arr.length; i += size) {
    chunks.push(arr.slice(i, i + size));
  }
  return chunks;
}
