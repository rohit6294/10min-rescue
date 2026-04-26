import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/driver_model.dart';
import '../models/hospital_model.dart';
import '../models/rescue_request_model.dart';
import '../models/sos_request_model.dart';
import '../constants/firestore_paths.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Driver ───────────────────────────────────────────────────────────────

  Future<DriverModel?> getDriver(String uid) async {
    final doc = await _db.doc(FirestorePaths.driver(uid)).get();
    if (!doc.exists) return null;
    return DriverModel.fromFirestore(doc);
  }

  Stream<DriverModel> watchDriver(String uid) => _db
      .doc(FirestorePaths.driver(uid))
      .snapshots()
      .map(DriverModel.fromFirestore);

  Future<void> setDriverOnline(String uid, bool isOnline) =>
      _db.doc(FirestorePaths.driver(uid)).set(
        {
          'isOnline': isOnline,
          'isAvailable': isOnline,
        },
        SetOptions(merge: true), // create doc if missing, otherwise update
      );

  // ─── Hospital ─────────────────────────────────────────────────────────────

  Future<HospitalModel?> getHospital(String uid) async {
    final doc = await _db.doc(FirestorePaths.hospital(uid)).get();
    if (!doc.exists) return null;
    return HospitalModel.fromFirestore(doc);
  }

  Stream<HospitalModel> watchHospital(String uid) => _db
      .doc(FirestorePaths.hospital(uid))
      .snapshots()
      .map(HospitalModel.fromFirestore);

  Future<void> setHospitalActive(String uid, bool isActive) =>
      _db.doc(FirestorePaths.hospital(uid)).set(
        {'isActive': isActive},
        SetOptions(merge: true),
      );

  // ─── Rescue Request ───────────────────────────────────────────────────────

  Future<RescueRequestModel?> getRequest(String requestId) async {
    final doc =
        await _db.doc(FirestorePaths.rescueRequest(requestId)).get();
    if (!doc.exists) return null;
    return RescueRequestModel.fromFirestore(doc);
  }

  Stream<RescueRequestModel> watchRequest(String requestId) => _db
      .doc(FirestorePaths.rescueRequest(requestId))
      .snapshots()
      .map(RescueRequestModel.fromFirestore);

  /// Driver accepts a request using a transaction to prevent race conditions.
  /// Returns true if this driver won, false if someone else already accepted.
  Future<bool> driverAcceptRequest(
      String requestId, String driverId) async {
    bool accepted = false;
    await _db.runTransaction((tx) async {
      final ref = _db.doc(FirestorePaths.rescueRequest(requestId));
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null || data['assignedDriverId'] != null) return; // Already taken

      tx.update(ref, {
        'assignedDriverId': driverId,
        'assignedDriverAcceptedAt': FieldValue.serverTimestamp(),
        'status': RequestStatus.driverAssigned.value,
      });
      accepted = true;
    });
    if (accepted) {
      await _db.doc(FirestorePaths.driver(driverId)).update({
        'isAvailable': false,
        'currentRequestId': requestId,
      });
    }
    return accepted;
  }

  /// Hospital accepts a request — same transaction pattern.
  Future<bool> hospitalAcceptRequest(
      String requestId, String hospitalId) async {
    bool accepted = false;
    await _db.runTransaction((tx) async {
      final ref = _db.doc(FirestorePaths.rescueRequest(requestId));
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null || data['assignedHospitalId'] != null) return;

      tx.update(ref, {
        'assignedHospitalId': hospitalId,
        'assignedHospitalAcceptedAt': FieldValue.serverTimestamp(),
        'status': RequestStatus.hospitalAssigned.value,
      });
      accepted = true;
    });
    if (accepted) {
      await _db.doc(FirestorePaths.hospital(hospitalId)).update({
        'isActive': false,
        'currentRequestId': requestId,
      });
    }
    return accepted;
  }

  Future<void> confirmPatientPickup(String requestId) =>
      _db.doc(FirestorePaths.rescueRequest(requestId)).update({
        'status': RequestStatus.patientPickedUp.value,
        'patientPickedUpAt': FieldValue.serverTimestamp(),
      });

  Future<void> completeRide(String requestId, String driverId) async {
    await _db.doc(FirestorePaths.rescueRequest(requestId)).update({
      'status': RequestStatus.completed.value,
      'completedAt': FieldValue.serverTimestamp(),
    });
    await _db.doc(FirestorePaths.driver(driverId)).update({
      'isAvailable': true,
      'currentRequestId': null,
    });
  }

  Future<void> completeHospitalReceive(
      String requestId, String hospitalId) async {
    await _db.doc(FirestorePaths.hospital(hospitalId)).update({
      'isActive': true,
      'currentRequestId': null,
    });
  }

  // ─── Location Updates ─────────────────────────────────────────────────────

  Stream<Map<String, dynamic>?> watchDriverLocation(String driverId) =>
      _db.doc(FirestorePaths.locationUpdate(driverId)).snapshots().map(
        (snap) => snap.exists ? snap.data() as Map<String, dynamic> : null,
      );

  // ─── Active request for driver ────────────────────────────────────────────

  Stream<QuerySnapshot> watchActiveRequestForDriver(String driverId) =>
      _db
          .collection(FirestorePaths.rescueRequests)
          .where('assignedDriverId', isEqualTo: driverId)
          .where('status', whereIn: [
            RequestStatus.driverAssigned.value,
            RequestStatus.patientPickedUp.value,
            RequestStatus.hospitalAssigned.value,
            RequestStatus.inTransit.value,
          ])
          .snapshots();

  // ─── Active request for hospital ─────────────────────────────────────────

  Stream<QuerySnapshot> watchActiveRequestForHospital(String hospitalId) =>
      _db
          .collection(FirestorePaths.rescueRequests)
          .where('assignedHospitalId', isEqualTo: hospitalId)
          .where('status', whereIn: [
            RequestStatus.hospitalAssigned.value,
            RequestStatus.inTransit.value,
          ])
          .snapshots();

  // ─── Pending requests (replaces FCM — free Spark plan) ───────────────────

  /// Stream of all unassigned pending driver requests.
  /// The driver app filters client-side by distance and dismissed IDs.
  Stream<List<RescueRequestModel>> watchPendingDriverRequests() => _db
      .collection(FirestorePaths.rescueRequests)
      .where('status', isEqualTo: RequestStatus.pendingDriver.value)
      .snapshots()
      .map((snap) =>
          snap.docs.map(RescueRequestModel.fromFirestore).toList());

  /// Stream of all unassigned pending hospital requests.
  /// The hospital app filters client-side by distance and dismissed IDs.
  Stream<List<RescueRequestModel>> watchPendingHospitalRequests() => _db
      .collection(FirestorePaths.rescueRequests)
      .where('status', isEqualTo: RequestStatus.pendingHospital.value)
      .snapshots()
      .map((snap) =>
          snap.docs.map(RescueRequestModel.fromFirestore).toList());

  // ─── SOS Requests (from website /sos page) ───────────────────────────────

  /// Stream all pending SOS requests (status == 'pending')
  Stream<List<SosRequestModel>> watchPendingSosRequests() => _db
      .collection('sos_requests')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snap) =>
          snap.docs.map(SosRequestModel.fromFirestore).toList());

  /// Driver accepts a SOS request — marks it assigned
  Future<void> acceptSosRequest(String sosId, String driverId) async {
    // Pull the driver's profile so we can copy basic info into the SOS
    // doc — that lets the public location.html (and the hospital portal)
    // display the driver without needing read access to /drivers/{uid}.
    final drv = await getDriver(driverId);
    final updates = <String, dynamic>{
      'status': 'assigned',
      'driverId': driverId,
      'assignedAt': FieldValue.serverTimestamp(),
    };
    if (drv != null) {
      updates['driverName']    = drv.name;
      updates['driverPhone']   = drv.phone;
      updates['vehicleNumber'] = drv.vehicleNumber;
      if (drv.location != null) {
        updates['driverLat'] = drv.location!.latitude;
        updates['driverLng'] = drv.location!.longitude;
        updates['driverLocationUpdatedAt'] = FieldValue.serverTimestamp();
      }
    }
    await _db.collection('sos_requests').doc(sosId).update(updates);
    await _db.doc(FirestorePaths.driver(driverId)).set(
      {'isAvailable': false},
      SetOptions(merge: true),
    );
  }

  /// Push the driver's current GPS into the SOS doc so the customer's
  /// tracking page can render a live position without read access to
  /// /drivers.  Safe to call frequently — single-doc write.
  Future<void> updateSosDriverLocation(
    String sosId,
    double lat,
    double lng,
  ) =>
      _db.collection('sos_requests').doc(sosId).update({
        'driverLat': lat,
        'driverLng': lng,
        'driverLocationUpdatedAt': FieldValue.serverTimestamp(),
      });

  /// Driver confirms patient is in the ambulance — move the SOS into
  /// `patient_picked_up` status.  Hospitals were already notified at
  /// `assigned` time; this state transition just tells the driver app
  /// to reveal the hospital location card.
  Future<void> markPatientPickedUp(String sosId) =>
      _db.collection('sos_requests').doc(sosId).update({
        'status': 'patient_picked_up',
        'patientPickedUpAt': FieldValue.serverTimestamp(),
      });

  /// Driver completes a SOS request
  Future<void> completeSosRequest(String sosId, String driverId) async {
    await _db.collection('sos_requests').doc(sosId).update({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
    });
    await _db.doc(FirestorePaths.driver(driverId)).set(
      {'isAvailable': true},
      SetOptions(merge: true),
    );
  }

  /// Watch the SOS request assigned to this driver — emits whenever
  /// any field on the doc changes (e.g. hospital accepted).  Returns
  /// the SOS while it's in any active state (`assigned`,
  /// `awaiting_hospital`, `hospital_assigned`); emits null when
  /// resolved or cancelled.
  Stream<SosRequestModel?> watchAssignedSos(String driverId) => _db
      .collection('sos_requests')
      .where('driverId', isEqualTo: driverId)
      .snapshots()
      .map((snap) {
        const activeStatuses = {
          'assigned',
          'patient_picked_up',
        };
        final active = snap.docs
            .map(SosRequestModel.fromFirestore)
            .where((s) => activeStatuses.contains(s.status))
            .toList();
        return active.isEmpty ? null : active.first;
      });

  /// Create a new rescue request (triggered from the app or website integration)
  Future<String> createRescueRequest({
    required String patientName,
    required String patientPhone,
    required GeoPoint patientLocation,
    required String emergencyType,
  }) async {
    final ref = _db.collection(FirestorePaths.rescueRequests).doc();
    await ref.set({
      'requestId': ref.id,
      'patientName': patientName,
      'patientPhone': patientPhone,
      'patientLocation': patientLocation,
      'emergencyType': emergencyType,
      'status': RequestStatus.pendingDriver.value,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'currentDriverSearchRadius': 1,
      'notifiedDriverIds': [],
      'assignedDriverId': null,
      'currentHospitalSearchRadius': 1,
      'notifiedHospitalIds': [],
      'assignedHospitalId': null,
    });
    return ref.id;
  }
}
