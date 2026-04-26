import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/models/driver_model.dart';
import '../../../core/models/rescue_request_model.dart';
import '../../../core/models/sos_request_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/loading_overlay.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final _firestoreService = FirestoreService();
  final _locationService = LocationService();
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  bool _loading = false;

  final _dismissedRequestIds = <String>{};
  bool _navigating = false;

  Position? _currentPosition;
  StreamSubscription<Position>? _gpsSub;

  @override
  void initState() {
    super.initState();

    // Register this device's FCM token so the dispatcher Cloud Function
    // can push SOS alerts even when the app is backgrounded or killed.
    FcmService.instance.registerCurrentDriverToken();

    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen(
      (pos) {
        if (mounted) setState(() => _currentPosition = pos);
      },
      onError: (_) {
        // Permission not granted yet — user must tap Go Online to trigger permission request
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navigating = false;
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    super.dispose();
  }

  void _handlePendingRequests(List<RescueRequestModel> requests) {
    if (_navigating) return;

    for (final req in requests) {
      if (_dismissedRequestIds.contains(req.requestId)) continue;

      if (_currentPosition != null) {
        final dist = LocationService.distanceKm(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          req.patientLocation.latitude,
          req.patientLocation.longitude,
        );
        if (dist > 10) continue;
      }

      _dismissedRequestIds.add(req.requestId);
      _navigating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/driver/request/${req.requestId}');
      });
      return;
    }
  }

  Future<void> _toggleOnline(bool currentlyOnline) async {
    if (!currentlyOnline) {
      final granted = await _locationService.requestPermissions();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is required to go online.'),
            backgroundColor: AppColors.emergency,
          ),
        );
        return;
      }
    }
    setState(() => _loading = true);
    try {
      await _firestoreService.setDriverOnline(_uid, !currentlyOnline);
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
        child: StreamBuilder<DriverModel>(
          stream: _firestoreService.watchDriver(_uid),
          builder: (context, snapshot) {
            // Show meaningful error instead of spinning forever
            if (snapshot.hasError) {
              final err = snapshot.error.toString();
              final isPermission = err.contains('permission-denied') ||
                  err.contains('PERMISSION_DENIED');
              return _buildErrorState(
                icon: isPermission
                    ? Icons.lock_outline_rounded
                    : Icons.cloud_off_rounded,
                title: isPermission
                    ? 'Database Access Denied'
                    : 'Database Not Set Up',
                message: isPermission
                    ? 'Firestore security rules are blocking access.\nAsk admin to set rules to Test mode.'
                    : 'Firestore database is not created yet.\nGo to Firebase Console → Firestore Database → Create database.',
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.emergency),
                    SizedBox(height: 16),
                    Text('Loading your profile...',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              );
            }

            final driver = snapshot.data!;

            // Verification: rejected
            if (driver.verificationStatus == 'rejected') {
              return _buildRejectedState(driver);
            }

            // Verification: pending with docs already submitted
            if (driver.verificationStatus == 'pending' &&
                driver.documents.isNotEmpty) {
              return _buildPendingState();
            }

            // Verified OR documents is empty (old/legacy user) → normal flow
            return StreamBuilder<List<SosRequestModel>>(
              stream: driver.isOnline
                  ? _firestoreService.watchPendingSosRequests()
                  : const Stream.empty(),
              builder: (context, sosSnap) {
                final sosList = sosSnap.data ?? [];

                // Fire heads-up local notifications for new SOS the driver
                // hasn't seen yet (FcmService de-duplicates by sosId).
                if (driver.isOnline && sosList.isNotEmpty) {
                  for (final sos in sosList) {
                    final dist = _currentPosition == null
                        ? null
                        : LocationService.distanceKm(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                            sos.latitude,
                            sos.longitude,
                          );
                    FcmService.instance.notifyNewSos(
                      sosId: sos.id,
                      patientName: sos.patientName,
                      phone: sos.phone,
                      emergencyType: sos.emergencyType,
                      distanceKm: dist,
                    );
                  }
                }

                return StreamBuilder<List<RescueRequestModel>>(
                  stream: (driver.isOnline && driver.isAvailable)
                      ? _firestoreService.watchPendingDriverRequests()
                      : const Stream.empty(),
                  builder: (context, reqSnap) {
                    if (reqSnap.hasData && reqSnap.data!.isNotEmpty) {
                      _handlePendingRequests(reqSnap.data!);
                      // Also fire a notification for new rescue_requests.
                      for (final r in reqSnap.data!) {
                        FcmService.instance.notifyNewRescueRequest(
                          requestId: r.requestId,
                          patientName: r.patientName,
                          emergencyType: r.emergencyType,
                        );
                      }
                    }
                    return _buildBody(driver, sosList);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildRejectedState(DriverModel driver) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.emergency.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cancel_rounded,
                color: AppColors.emergency,
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Documents Rejected',
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (driver.rejectionReason.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.emergency.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.emergency.withValues(alpha: 0.2)),
                ),
                child: Text(
                  driver.rejectionReason,
                  style: const TextStyle(
                    color: AppColors.emergency,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Please re-upload your documents with clear, readable photos.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.go('/driver/upload-docs'),
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Re-upload Documents'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emergency,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) context.go('/auth/login');
              },
              icon: const Icon(Icons.logout, color: AppColors.textSecondary),
              label: const Text(
                'Sign Out',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.warningAmber.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.access_time_rounded,
                color: AppColors.warningAmber,
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Verification Pending',
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Your documents are under review. You\'ll be able to go online once verified.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) context.go('/auth/login');
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.navy,
                side: const BorderSide(color: AppColors.navy),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.emergency, size: 56),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) context.go('/auth/login');
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emergency,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(DriverModel driver, List<SosRequestModel> sosList) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // ── SOS Alert cards (shown when driver is online) ──────────────────
          if (sosList.isNotEmpty) ...[
            ...sosList.map((sos) => _SosAlertCard(
              sos: sos,
              driverPos: _currentPosition,
              onAccept: () async {
                await _firestoreService.acceptSosRequest(sos.id, _uid);
                if (mounted) context.go('/driver/sos/${sos.id}');
              },
            )),
            const SizedBox(height: 16),
          ],
          // Driver Avatar & Name
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
                    color: AppColors.accentBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.drive_eta_rounded,
                      color: AppColors.accentBlue, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.name.isEmpty ? 'Driver' : driver.name,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        driver.vehicleNumber.isEmpty
                            ? 'Vehicle not set'
                            : driver.vehicleNumber,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Online/Offline Toggle Card
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: driver.isOnline
                    ? [const Color(0xFF16A34A), const Color(0xFF15803D)]
                    : [AppColors.navy, AppColors.navyLight],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (driver.isOnline
                          ? const Color(0xFF16A34A)
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
                  driver.isOnline
                      ? Icons.sensors_rounded
                      : Icons.sensors_off_rounded,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  driver.isOnline ? 'You are ONLINE' : 'You are OFFLINE',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  driver.isOnline
                      ? 'Waiting for emergency requests...'
                      : 'Toggle to start receiving requests',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => _toggleOnline(driver.isOnline),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: driver.isOnline
                          ? Colors.white.withValues(alpha: 0.15)
                          : AppColors.emergency,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4), width: 3),
                    ),
                    child: Icon(
                      driver.isOnline
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  driver.isOnline ? 'Tap to go Offline' : 'Tap to go Online',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Status info
          if (driver.isOnline && driver.currentRequestId != null)
            _statusTile(
              icon: Icons.emergency_rounded,
              color: AppColors.emergency,
              title: 'Active Request',
              subtitle: 'Tap to view current request',
              onTap: () => context
                  .go('/driver/navigate-patient/${driver.currentRequestId}'),
            )
          else if (driver.isOnline)
            _statusTile(
              icon: Icons.check_circle_outline,
              color: AppColors.onlineGreen,
              title: 'Ready for Requests',
              subtitle: "You'll be notified when there's an emergency nearby",
            ),
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

// ── SOS Alert Card ────────────────────────────────────────────────────────────

class _SosAlertCard extends StatefulWidget {
  final SosRequestModel sos;
  final Position? driverPos;
  final VoidCallback onAccept;

  const _SosAlertCard({
    required this.sos,
    required this.driverPos,
    required this.onAccept,
  });

  @override
  State<_SosAlertCard> createState() => _SosAlertCardState();
}

class _SosAlertCardState extends State<_SosAlertCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  double? get _distKm {
    if (widget.driverPos == null) return null;
    return LocationService.distanceKm(
      widget.driverPos!.latitude,
      widget.driverPos!.longitude,
      widget.sos.latitude,
      widget.sos.longitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dist = _distKm;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          color: Color.lerp(
            AppColors.emergency.withValues(alpha: 0.08),
            AppColors.emergency.withValues(alpha: 0.18),
            _pulse.value,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.emergency.withValues(alpha: 0.5 + _pulse.value * 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.emergency.withValues(alpha: 0.15 + _pulse.value * 0.1),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: child,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.emergency,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.emergency_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '🚨 EMERGENCY SOS',
                            style: TextStyle(
                              color: AppColors.emergency,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (widget.sos.emergencyType != null &&
                              widget.sos.emergencyType!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.emergency
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.sos.emergencyType!,
                                style: const TextStyle(
                                  color: AppColors.emergency,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        widget.sos.patientName?.isNotEmpty == true
                            ? widget.sos.patientName!
                            : 'Customer needs immediate help!',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.sos.phone != null &&
                          widget.sos.phone!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '📞 ${widget.sos.phone}',
                          style: const TextStyle(
                              color: AppColors.accentBlue, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                if (dist != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.emergency.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${dist.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        color: AppColors.emergency,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Accept button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _accepting
                    ? null
                    : () async {
                        setState(() => _accepting = true);
                        widget.onAccept();
                      },
                icon: _accepting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(_accepting ? 'Accepting...' : 'Accept & Navigate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emergency,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
