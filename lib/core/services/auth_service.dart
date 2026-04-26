import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/driver_model.dart';
import '../models/hospital_model.dart';
import '../constants/firestore_paths.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<void> signOut() => _auth.signOut();

  Future<void> registerDriver({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String vehicleNumber,
    required String licenseNumber,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;

    final user = UserModel(
      uid: uid,
      email: email,
      displayName: name,
      phone: phone,
      role: UserRole.driver,
      createdAt: DateTime.now(),
    );
    final driver = DriverModel(
      uid: uid,
      name: name,
      phone: phone,
      vehicleNumber: vehicleNumber,
      licenseNumber: licenseNumber,
      verificationStatus: 'pending',
    );

    final batch = _db.batch();
    batch.set(_db.doc(FirestorePaths.user(uid)), user.toFirestore());
    batch.set(_db.doc(FirestorePaths.driver(uid)), driver.toFirestore());
    try {
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> registerHospital({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String address,
    required List<String> specializations,
    GeoPoint? location,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;

    final user = UserModel(
      uid: uid,
      email: email,
      displayName: name,
      phone: phone,
      role: UserRole.hospital,
      createdAt: DateTime.now(),
    );
    final hospital = HospitalModel(
      uid: uid,
      name: name,
      phone: phone,
      address: address,
      specializations: specializations,
      location: location, // nullable — hospital can update location later
    );

    final batch = _db.batch();
    batch.set(_db.doc(FirestorePaths.user(uid)), user.toFirestore());
    batch.set(_db.doc(FirestorePaths.hospital(uid)), hospital.toFirestore());
    await batch.commit();
  }

  Future<UserRole?> getUserRole(String uid) async {
    final doc = await _db.doc(FirestorePaths.user(uid)).get();
    if (!doc.exists) return null;
    final data = doc.data() as Map<String, dynamic>;
    return data['role'] == 'driver' ? UserRole.driver : UserRole.hospital;
  }
}
