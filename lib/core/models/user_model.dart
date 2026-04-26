import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { driver, hospital }

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String phone;
  final UserRole role;
  final String fcmToken;
  final bool isActive;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.phone,
    required this.role,
    this.fcmToken = '',
    this.isActive = false,
    required this.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] == 'driver' ? UserRole.driver : UserRole.hospital,
      fcmToken: data['fcmToken'] ?? '',
      isActive: data['isActive'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'phone': phone,
        'role': role == UserRole.driver ? 'driver' : 'hospital',
        'fcmToken': fcmToken,
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
