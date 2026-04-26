import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/models/hospital_model.dart';
import '../../../core/models/rescue_request_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/loading_overlay.dart';

class HospitalHomeScreen extends StatefulWidget {
  const HospitalHomeScreen({super.key});

  @override
  State<HospitalHomeScreen> createState() => _HospitalHomeScreenState();
}

class _HospitalHomeScreenState extends State<HospitalHomeScreen> {
  final _firestoreService = FirestoreService();
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  bool _loading = false;

  // Request IDs already shown — prevents re-navigating after decline
  final _dismissedRequestIds = <String>{};
  bool _navigating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navigating = false;
  }

  /// Called on every stream emission. Navigates to the first nearby,
  /// non-dismissed pending hospital request.
  void _handlePendingRequests(
    List<RescueRequestModel> requests,
    HospitalModel hospital,
  ) {
    if (_navigating || hospital.location == null) return;

    for (final req in requests) {
      if (_dismissedRequestIds.contains(req.requestId)) continue;

      final dist = LocationService.distanceKm(
        hospital.location!.latitude,
        hospital.location!.longitude,
        req.patientLocation.latitude,
        req.patientLocation.longitude,
      );

      if (dist <= 20) {
        _dismissedRequestIds.add(req.requestId);
        _navigating = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
              context.go('/hospital/ambulance/${req.requestId}');
        });
        return;
      }
    }
  }

  Future<void> _toggleActive(bool currentlyActive) async {
    setState(() => _loading = true);
    try {
      await _firestoreService.setHospitalActive(_uid, !currentlyActive);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      appBar: AppBar(
        title: const Text('10Min Rescue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              context.go('/auth/login');
            },
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _loading,
        child: StreamBuilder<HospitalModel>(
          stream: _firestoreService.watchHospital(_uid),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: AppColors.emergency));
            }
            final hospital = snapshot.data!;

            // When active, watch pending hospital requests via Firestore
            // (replaces FCM — works on free Spark plan)
            return StreamBuilder<List<RescueRequestModel>>(
              stream: hospital.isActive
                  ? _firestoreService.watchPendingHospitalRequests()
                  : const Stream.empty(),
              builder: (context, reqSnap) {
                if (reqSnap.hasData && reqSnap.data!.isNotEmpty) {
                  _handlePendingRequests(reqSnap.data!, hospital);
                }
                return _buildBody(hospital);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(HospitalModel hospital) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Hospital info card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.emergency.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.local_hospital_rounded,
                      color: AppColors.emergency, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hospital.name,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        hospital.address,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Active/Inactive toggle
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hospital.isActive
                    ? [const Color(0xFF7C3AED), const Color(0xFF6D28D9)]
                    : [AppColors.navy, AppColors.navyLight],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (hospital.isActive
                          ? const Color(0xFF7C3AED)
                          : AppColors.navy)
                      .withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  hospital.isActive
                      ? Icons.local_hospital_rounded
                      : Icons.local_hospital_outlined,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  hospital.isActive ? 'ACCEPTING PATIENTS' : 'NOT ACCEPTING',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  hospital.isActive
                      ? 'You will receive ambulance notifications'
                      : 'Toggle to start accepting emergency patients',
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => _toggleActive(hospital.isActive),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hospital.isActive
                          ? Colors.white.withValues(alpha: 0.15)
                          : AppColors.emergency,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4), width: 3),
                    ),
                    child: Icon(
                      hospital.isActive
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  hospital.isActive ? 'Tap to stop accepting' : 'Tap to start accepting',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (hospital.isActive && hospital.currentRequestId != null)
            _statusTile(
              icon: Icons.directions_car_rounded,
              color: const Color(0xFF7C3AED),
              title: 'Ambulance Incoming',
              subtitle: 'Tap to track ambulance',
              onTap: () => context
                  .go('/hospital/track/${hospital.currentRequestId}'),
            )
          else if (hospital.isActive)
            _statusTile(
              icon: Icons.check_circle_outline,
              color: AppColors.onlineGreen,
              title: 'Ready to Receive',
              subtitle: 'You\'ll get a notification when an ambulance is assigned',
            ),

          if (hospital.specializations.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Specializations',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: AppColors.navy)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: hospital.specializations
                        .map((s) => Chip(
                              label: Text(s,
                                  style: const TextStyle(fontSize: 12)),
                              backgroundColor:
                                  AppColors.accentBlue.withValues(alpha: 0.1),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.bold)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.arrow_forward_ios,
                  color: AppColors.textLight, size: 14),
          ],
        ),
      ),
    );
  }
}
