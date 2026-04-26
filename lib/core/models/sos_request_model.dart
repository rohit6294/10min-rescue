import 'package:cloud_firestore/cloud_firestore.dart';

class SosRequestModel {
  final String id;
  final double latitude;
  final double longitude;
  final String mapsLink;
  final String status; // pending | assigned | resolved
  final String? driverId;
  final String? phone;
  final String? patientName;
  final String? emergencyType;
  final double? accuracy;
  final DateTime? createdAt;

  // Driver-side fields written by the Flutter driver app once the SOS
  // is accepted.  Used by the public location.html tracking UI.
  final String? driverName;
  final String? driverPhone;
  final String? vehicleNumber;
  final double? driverLat;
  final double? driverLng;
  final DateTime? driverLocationUpdatedAt;

  // Hospital-side fields written by the hospital portal when a hospital
  // accepts an in-progress SOS.  Lets the driver navigate to that
  // hospital and shows the customer where they're being taken.
  final String? assignedHospitalId;
  final String? hospitalName;
  final String? hospitalPhone;
  final String? hospitalAddress;
  final double? hospitalLat;
  final double? hospitalLng;

  const SosRequestModel({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.mapsLink,
    required this.status,
    this.driverId,
    this.phone,
    this.patientName,
    this.emergencyType,
    this.accuracy,
    this.createdAt,
    this.driverName,
    this.driverPhone,
    this.vehicleNumber,
    this.driverLat,
    this.driverLng,
    this.driverLocationUpdatedAt,
    this.assignedHospitalId,
    this.hospitalName,
    this.hospitalPhone,
    this.hospitalAddress,
    this.hospitalLat,
    this.hospitalLng,
  });

  factory SosRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return SosRequestModel(
      id: doc.id,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      mapsLink: data['mapsLink'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      driverId: data['driverId'] as String?,
      phone: data['phone'] as String?,
      patientName: data['patientName'] as String?,
      emergencyType: data['emergencyType'] as String?,
      accuracy: (data['accuracy'] as num?)?.toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      driverName: data['driverName'] as String?,
      driverPhone: data['driverPhone'] as String?,
      vehicleNumber: data['vehicleNumber'] as String?,
      driverLat: (data['driverLat'] as num?)?.toDouble(),
      driverLng: (data['driverLng'] as num?)?.toDouble(),
      driverLocationUpdatedAt:
          (data['driverLocationUpdatedAt'] as Timestamp?)?.toDate(),
      assignedHospitalId: data['assignedHospitalId'] as String?,
      hospitalName: data['hospitalName'] as String?,
      hospitalPhone: data['hospitalPhone'] as String?,
      hospitalAddress: data['hospitalAddress'] as String?,
      hospitalLat: (data['hospitalLat'] as num?)?.toDouble(),
      hospitalLng: (data['hospitalLng'] as num?)?.toDouble(),
    );
  }
}
