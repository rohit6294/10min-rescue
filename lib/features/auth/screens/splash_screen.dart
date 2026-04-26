import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      context.go('/auth/login');
    } else {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('drivers')
            .doc(user.uid)
            .get();

        if (!doc.exists) {
          // No driver document — send to upload docs
          context.go('/driver/upload-docs');
          return;
        }

        final data = (doc.data() as Map<String, dynamic>?) ?? {};
        final verificationStatus =
            data['verificationStatus'] as String? ?? 'pending';
        final documents =
            (data['documents'] as Map<String, dynamic>?) ?? {};

        if (verificationStatus == 'verified') {
          context.go('/driver/home');
        } else if (verificationStatus == 'pending' ||
            verificationStatus == 'rejected') {
          if (documents.isEmpty) {
            context.go('/driver/upload-docs');
          } else {
            context.go('/driver/home');
          }
        } else {
          context.go('/driver/home');
        }
      } catch (_) {
        // Firestore failed — navigate home gracefully
        context.go('/driver/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.emergency,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.emergency.withValues(alpha: 0.4),
                    blurRadius: 24,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: const Icon(Icons.emergency, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 28),
            const Text(
              '10Min',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            const Text(
              'Rescue',
              style: TextStyle(
                color: AppColors.emergency,
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Emergency Ambulance Platform',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 64),
            const CircularProgressIndicator(
              color: AppColors.emergency,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}
