import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { findNearbyHospitalsInternal } from "./findNearbyHospitals";

const db = admin.firestore();

/**
 * Cloud Tasks HTTP endpoint — fires 30s after findNearbyHospitals.
 * If no hospital accepted, expand radius by +1km and search again.
 */
export const onHospitalTimeout = functions
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

    // Skip if hospital already assigned
    if (
      request.assignedHospitalId ||
      (request.status !== "pending_hospital" &&
        request.status !== "driver_assigned")
    ) {
      res.status(200).send("Already handled");
      return;
    }

    const newRadius: number = currentRadius + 1;
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

    const patientLat = (request.patientLocation as admin.firestore.GeoPoint).latitude;
    const patientLng = (request.patientLocation as admin.firestore.GeoPoint).longitude;
    const alreadyNotified = (request.notifiedHospitalIds as string[]) || [];

    await findNearbyHospitalsInternal({
      requestId,
      lat: patientLat,
      lng: patientLng,
      searchRadius: newRadius,
      alreadyNotified,
    });

    res.status(200).send(`Hospital radius expanded to ${newRadius}km`);
  });
