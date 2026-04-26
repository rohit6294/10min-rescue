import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/models/rescue_request_model.dart';
import '../../../core/constants/app_colors.dart';

class NavigateToPatientScreen extends StatefulWidget {
  final String requestId;
  const NavigateToPatientScreen({super.key, required this.requestId});

  @override
  State<NavigateToPatientScreen> createState() =>
      _NavigateToPatientScreenState();
}

class _NavigateToPatientScreenState extends State<NavigateToPatientScreen> {
  final _firestoreService = FirestoreService();
  final _locationService = LocationService();
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  final _mapController = MapController();

  LatLng? _driverLocation;
  LatLng? _patientLocation;

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  void _startLocationTracking() {
    _locationService.startTracking(
      driverId: _uid,
      requestId: widget.requestId,
      onPosition: (Position pos) {
        if (!mounted) return;
        final newLoc = LatLng(pos.latitude, pos.longitude);
        setState(() => _driverLocation = newLoc);
        // Keep map centered on driver
        _mapController.move(newLoc, _mapController.camera.zoom);
      },
    );
  }

  bool _isNearPatient() {
    if (_driverLocation == null || _patientLocation == null) return false;
    return LocationService.distanceKm(
          _driverLocation!.latitude,
          _driverLocation!.longitude,
          _patientLocation!.latitude,
          _patientLocation!.longitude,
        ) <=
        0.15; // 150 metres
  }

  @override
  void dispose() {
    _locationService.stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigate to Patient'),
        backgroundColor: AppColors.navy,
        leading: const SizedBox.shrink(),
      ),
      body: StreamBuilder<RescueRequestModel>(
        stream: _firestoreService.watchRequest(widget.requestId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.emergency));
          }
          final request = snapshot.data!;
          _patientLocation = LatLng(
            request.patientLocation.latitude,
            request.patientLocation.longitude,
          );

          return Column(
            children: [
              Expanded(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter:
                        _patientLocation ?? const LatLng(22.5726, 88.3639),
                    initialZoom: 14,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.tenminrescue.ten_min_res',
                    ),
                    MarkerLayer(
                      markers: [
                        // Patient marker
                        if (_patientLocation != null)
                          Marker(
                            point: _patientLocation!,
                            width: 48,
                            height: 48,
                            child: const Icon(
                              Icons.person_pin_circle,
                              color: AppColors.emergency,
                              size: 44,
                            ),
                          ),
                        // Driver (ambulance) marker
                        if (_driverLocation != null)
                          Marker(
                            point: _driverLocation!,
                            width: 48,
                            height: 48,
                            child: const Icon(
                              Icons.drive_eta_rounded,
                              color: Colors.blue,
                              size: 40,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Bottom sheet
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.emergency.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.person_pin_circle,
                              color: AppColors.emergency),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                request.patientName,
                                style: const TextStyle(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                request.emergencyType,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isNearPatient()
                            ? () => context.go(
                                '/driver/pickup-confirm/${widget.requestId}')
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.onlineGreen,
                          disabledBackgroundColor: Colors.grey.shade300,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _isNearPatient()
                              ? '✓ Patient Picked Up'
                              : 'Approaching Patient...',
                          style: TextStyle(
                            color: _isNearPatient()
                                ? Colors.white
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
