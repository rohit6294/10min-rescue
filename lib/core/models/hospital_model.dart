import 'package:cloud_firestore/cloud_firestore.dart';

class HospitalModel {
  final String uid;
  final String name;
  final String phone;
  final String address;
  final String fcmToken;
  final bool isActive;
  final GeoPoint? location;
  final String geohash;
  final List<String> specializations;
  final String? currentRequestId;

  const HospitalModel({
    required this.uid,
    required this.name,
    required this.phone,
    this.address = '',
    this.fcmToken = '',
    this.isActive = false,
    this.location,
    this.geohash = '',
    this.specializations = const [],
    this.currentRequestId,
  });

  factory HospitalModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HospitalModel(
      uid: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'] ?? '',
      fcmToken: data['fcmToken'] ?? '',
      isActive: data['isActive'] ?? false,
      location: data['location'] as GeoPoint?,
      geohash: data['geohash'] ?? '',
      specializations: List<String>.from(data['specializations'] ?? []),
      currentRequestId: data['currentRequestId'],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'name': name,
        'phone': phone,
        'address': address,
        'fcmToken': fcmToken,
        'isActive': isActive,
        if (location != null) 'location': location,
        'geohash': geohash,
        'specializations': specializations,
        'currentRequestId': currentRequestId,
      };

  HospitalModel copyWith({
    bool? isActive,
    GeoPoint? location,
    String? geohash,
    String? currentRequestId,
    String? fcmToken,
  }) =>
      HospitalModel(
        uid: uid,
        name: name,
        phone: phone,
        address: address,
        fcmToken: fcmToken ?? this.fcmToken,
        isActive: isActive ?? this.isActive,
        location: location ?? this.location,
        geohash: geohash ?? this.geohash,
        specializations: specializations,
        currentRequestId: currentRequestId ?? this.currentRequestId,
      );
}
