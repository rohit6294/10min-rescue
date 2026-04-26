import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../../../core/services/firestore_service.dart';
import '../../../core/models/rescue_request_model.dart';
import '../../../core/constants/app_colors.dart';

class IncomingAmbulanceScreen extends StatefulWidget {
  final String requestId;
  const IncomingAmbulanceScreen({super.key, required this.requestId});

  @override
  State<IncomingAmbulanceScreen> createState() =>
      _IncomingAmbulanceScreenState();
}

class _IncomingAmbulanceScreenState extends State<IncomingAmbulanceScreen>
    with SingleTickerProviderStateMixin {
  final _firestoreService = FirestoreService();
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  int _secondsLeft = 30;
  Timer? _countdownTimer;
  late AnimationController _pulseController;
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        if (mounted) context.go('/hospital/home');
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _accept() async {
    if (_accepting) return;
    setState(() => _accepting = true);
    _countdownTimer?.cancel();

    final won = await _firestoreService.hospitalAcceptRequest(
        widget.requestId, _uid);
    if (!mounted) return;

    if (won) {
      context.go('/hospital/track/${widget.requestId}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Already accepted by another hospital.'),
          backgroundColor: AppColors.emergency,
        ),
      );
      context.go('/hospital/home');
    }
  }

  void _decline() {
    _countdownTimer?.cancel();
    context.go('/hospital/home');
  }

  Color get _timerColor {
    if (_secondsLeft > 15) return AppColors.timerNormal;
    if (_secondsLeft > 7) return AppColors.timerWarning;
    return AppColors.timerCritical;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: StreamBuilder<RescueRequestModel>(
        stream: _firestoreService.watchRequest(widget.requestId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.emergency));
          }
          final request = snapshot.data!;

          if (request.assignedHospitalId != null &&
              request.assignedHospitalId != _uid) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) context.go('/hospital/home');
            });
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // Countdown
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          value: _secondsLeft / 30,
                          color: _timerColor,
                          backgroundColor: Colors.white12,
                          strokeWidth: 6,
                        ),
                      ),
                      Text(
                        '$_secondsLeft',
                        style: TextStyle(
                          color: _timerColor,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Respond within $_secondsLeft seconds',
                    style: TextStyle(color: _timerColor, fontSize: 13),
                  ),
                  const Spacer(),

                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, __) => Transform.scale(
                      scale: 1.0 + _pulseController.value * 0.12,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.directions_car_rounded,
                            color: Colors.amber, size: 52),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '🚑 Ambulance Incoming',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    request.emergencyType.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2),
                  ),
                  const Spacer(),

                  // Request info
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Column(
                      children: [
                        _infoRow(Icons.person_outline, 'Patient',
                            request.patientName),
                        const Divider(color: Colors.white12, height: 20),
                        _infoRow(Icons.emergency, 'Emergency',
                            request.emergencyType),
                        const Divider(color: Colors.white12, height: 20),
                        _infoRow(
                          Icons.radar,
                          'Search Radius',
                          '${request.currentHospitalSearchRadius} km',
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _accepting ? null : _decline,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white54,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Decline'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _accepting ? null : _accept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.onlineGreen,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _accepting
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('✓ ACCEPT',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 18),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
