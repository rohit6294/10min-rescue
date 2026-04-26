import 'package:cloud_firestore/cloud_firestore.dart';

enum RequestStatus {
  pendingDriver,
  driverAssigned,
  patientPickedUp,
  pendingHospital,
  hospitalAssigned,
  inTransit,
  completed,
  cancelled,
}

extension RequestStatusX on RequestStatus {
  String get value {
    switch (this) {
      case RequestStatus.pendingDriver:
        return 'pending_driver';
      case RequestStatus.driverAssigned:
        return 'driver_assigned';
      case RequestStatus.patientPickedUp:
        return 'patient_picked_up';
      case RequestStatus.pendingHospital:
        return 'pending_hospital';
      case RequestStatus.hospitalAssigned:
        return 'hospital_assigned';
      case RequestStatus.inTransit:
        return 'in_transit';
      case RequestStatus.completed:
        return 'completed';
      case RequestStatus.cancelled:
        return 'cancelled';
    }
  }

  static RequestStatus fromString(String s) {
    switch (s) {
      case 'driver_assigned':
        return RequestStatus.driverAssigned;
      case 'patient_picked_up':
        return RequestStatus.patientPickedUp;
      case 'pending_hospital':
        return RequestStatus.pendingHospital;
      case 'hospital_assigned':
        return RequestStatus.hospitalAssigned;
      case 'in_transit':
        return RequestStatus.inTransit;
      case 'completed':
        return RequestStatus.completed;
      case 'cancelled':
        return RequestStatus.cancelled;
      default:
        return RequestStatus.pendingDriver;
    }
  }
}

class RescueRequestModel {
  final String requestId;
  final String patientName;
  final String patientPhone;
  final GeoPoint patientLocation;
  final String emergencyType;
  final RequestStatus status;
  final DateTime createdAt;

  // Driver phase
  final int currentDriverSearchRadius;
  final List<String> notifiedDriverIds;
  final String? assignedDriverId;

  // Hospital phase
  final int currentHospitalSearchRadius;
  final List<String> notifiedHospitalIds;
  final String? assignedHospitalId;

  const RescueRequestModel({
    required this.requestId,
    required this.patientName,
    required this.patientPhone,
    required this.patientLocation,
    this.emergencyType = 'general',
    required this.status,
    required this.createdAt,
    this.currentDriverSearchRadius = 1,
    this.notifiedDriverIds = const [],
    this.assignedDriverId,
    this.currentHospitalSearchRadius = 1,
    this.notifiedHospitalIds = const [],
    this.assignedHospitalId,
  });

  factory RescueRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RescueRequestModel(
      requestId: doc.id,
      patientName: data['patientName'] ?? 'Unknown Patient',
      patientPhone: data['patientPhone'] ?? '',
      patientLocation: data['patientLocation'] as GeoPoint? ?? const GeoPoint(0, 0),
      emergencyType: data['emergencyType'] ?? 'general',
      status: RequestStatusX.fromString(data['status'] ?? 'pending_driver'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      currentDriverSearchRadius: data['currentDriverSearchRadius'] ?? 1,
      notifiedDriverIds: List<String>.from(data['notifiedDriverIds'] ?? []),
      assignedDriverId: data['assignedDriverId'],
      currentHospitalSearchRadius: data['currentHospitalSearchRadius'] ?? 1,
      notifiedHospitalIds: List<String>.from(data['notifiedHospitalIds'] ?? []),
      assignedHospitalId: data['assignedHospitalId'],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'patientName': patientName,
        'patientPhone': patientPhone,
        'patientLocation': patientLocation,
        'emergencyType': emergencyType,
        'status': status.value,
        'createdAt': FieldValue.serverTimestamp(),
        'currentDriverSearchRadius': currentDriverSearchRadius,
        'notifiedDriverIds': notifiedDriverIds,
        'assignedDriverId': assignedDriverId,
        'currentHospitalSearchRadius': currentHospitalSearchRadius,
        'notifiedHospitalIds': notifiedHospitalIds,
        'assignedHospitalId': assignedHospitalId,
      };
}
