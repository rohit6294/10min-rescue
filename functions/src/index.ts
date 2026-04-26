import * as admin from "firebase-admin";
admin.initializeApp();

// Export all functions
export { findNearbyDrivers } from "./findNearbyDrivers";
export { onDriverAccept } from "./onDriverAccept";
export { onDriverTimeout } from "./onDriverTimeout";
export { findNearbyHospitals } from "./findNearbyHospitals";
export { onHospitalAccept } from "./onHospitalAccept";
export { onHospitalTimeout } from "./onHospitalTimeout";
export { updateDriverLocation } from "./updateDriverLocation";

// onSosCreated requires the Blaze (paid) Firebase plan to deploy.
// Source kept in `./onSosCreated.ts` for future enable — uncomment
// the line below once the project is upgraded to Blaze.
// export { onSosCreated } from "./onSosCreated";
