import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { findNearbyDriversInternal } from "./findNearbyDrivers";

const db = admin.firestore();

/**
 * Cloud Tasks HTTP endpoint — fires 30s after findNearbyDrivers.
 * If no driver accepted, expand radius by +1km and search again.
 */
export const onDriverTimeout = functions
  .region("asia-south1")
  .https.onRequest(async (req, res) => {
    const { requestId, currentRadius } = req.body as {
      requestId: string;
      currentRadius: number;
    };

    const requestRef = db.collection("rescue_requests").doc(requestId);
    const requestSnap = await requestRef.get();

    if (!requestSnap.exists) {
      res.status(200).send("Request not found");
      return;
    }

    const request = requestSnap.data()!;

    // Skip if driver already assigned or request is no longer pending
    if (request.assignedDriverId || request.status !== "pending_driver") {
      res.status(200).send("Already handled");
      return;
    }

    const newRadius: number = currentRadius + 1;
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

    const patientLat = (request.patientLocation as admin.firestore.GeoPoint).latitude;
    const patientLng = (request.patientLocation as admin.firestore.GeoPoint).longitude;
    const alreadyNotified = (request.notifiedDriverIds as string[]) || [];

    await findNearbyDriversInternal({
      requestId,
      lat: patientLat,
      lng: patientLng,
      searchRadius: newRadius,
      alreadyNotified,
    });

    res.status(200).send(`Radius expanded to ${newRadius}km`);
  });
