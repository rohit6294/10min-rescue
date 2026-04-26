import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Triggers whenever a new SOS request is written to /sos_requests.
 *
 * For now we broadcast the alert to **every verified online driver**
 * — drivers see distance in the alert card and decide whether to
 * accept.  Once we have enough density we can replace this with a
 * geohash-bounded query (see findNearbyDrivers.ts for reference).
 *
 * Sends BOTH a notification + data payload so:
 *   - Killed/background app: Android system tray shows the alert.
 *   - Foreground app: fcm_service.dart catches the data and shows a
 *     local high-priority notification.
 *
 * Tapping the notification routes the driver to /driver/sos/<sosId>.
 */
export const onSosCreated = functions
  .region("asia-south1")
  .firestore.document("sos_requests/{sosId}")
  .onCreate(async (snap, context) => {
    const sosId = context.params.sosId;
    const sos = snap.data() as Record<string, unknown>;

    // Only push for newly-pending SOS (skip if already assigned at create-time).
    if (sos.status !== "pending") {
      console.log(`SOS ${sosId} not pending — skipping push`);
      return null;
    }

    // Pull every verified, online driver.
    const driverSnap = await db
      .collection("drivers")
      .where("verificationStatus", "==", "verified")
      .where("isOnline", "==", true)
      .get();

    const tokens: string[] = [];
    driverSnap.forEach((doc) => {
      const t = doc.data().fcmToken as string | undefined;
      if (t && t.length > 0) tokens.push(t);
    });

    if (tokens.length === 0) {
      console.log(`SOS ${sosId} — no online drivers with FCM tokens.`);
      return null;
    }

    const phone = (sos.phone as string) || "";
    const patientName = (sos.patientName as string) || "";
    const emergencyType = (sos.emergencyType as string) || "";
    const lat = sos.latitude as number;
    const lng = sos.longitude as number;

    const titleBits = ["🚨 EMERGENCY SOS"];
    if (emergencyType) titleBits.push("·", emergencyType);
    const title = titleBits.join(" ");

    const bodyBits: string[] = [];
    if (patientName) bodyBits.push(patientName);
    if (phone) bodyBits.push(phone);
    bodyBits.push(`Location: ${Number(lat).toFixed(4)}, ${Number(lng).toFixed(4)}`);
    const body = bodyBits.join(" · ");

    // Send in chunks of 500 (FCM multicast limit).
    const chunks = chunk(tokens, 500);
    let success = 0;
    let failed = 0;

    await Promise.all(
      chunks.map(async (slice) => {
        const resp = await messaging.sendEachForMulticast({
          tokens: slice,
          notification: { title, body },
          data: {
            type: "sos",
            id: sosId,
            phone,
            patientName,
            emergencyType,
            latitude: String(lat),
            longitude: String(lng),
          },
          android: {
            priority: "high",
            notification: {
              channelId: "sos_emergency",
              sound: "default",
              priority: "max",
              defaultVibrateTimings: true,
              defaultLightSettings: true,
              color: "#FF3B3B",
              tag: `sos-${sosId}`,
            },
          },
          apns: {
            headers: { "apns-priority": "10" },
            payload: {
              aps: {
                sound: "default",
                badge: 1,
                category: "sos",
                "content-available": 1,
              },
            },
          },
        });
        success += resp.successCount;
        failed += resp.failureCount;

        // Cleanup: remove invalid tokens from the drivers collection.
        const deadIndexes: number[] = [];
        resp.responses.forEach((r, i) => {
          if (!r.success) {
            const code = r.error?.code || "";
            if (
              code === "messaging/invalid-registration-token" ||
              code === "messaging/registration-token-not-registered"
            ) {
              deadIndexes.push(i);
            }
          }
        });
        if (deadIndexes.length > 0) {
          const deadTokens = deadIndexes.map((i) => slice[i]);
          await purgeDeadTokens(deadTokens);
        }
      })
    );

    console.log(
      `SOS ${sosId} pushed → ${success} delivered, ${failed} failed, ${tokens.length} drivers attempted`
    );
    return { success, failed, attempted: tokens.length };
  });

async function purgeDeadTokens(deadTokens: string[]): Promise<void> {
  const drvSnap = await db
    .collection("drivers")
    .where("fcmToken", "in", deadTokens.slice(0, 10))
    .get();
  const batch = db.batch();
  drvSnap.forEach((doc) => {
    batch.update(doc.ref, { fcmToken: admin.firestore.FieldValue.delete() });
  });
  if (!drvSnap.empty) await batch.commit();
}

function chunk<T>(arr: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}
