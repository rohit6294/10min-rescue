import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/models/rescue_request_model.dart';
import '../../../core/models/hospital_model.dart';
import '../../../core/constants/app_colors.dart';

class NavigateToHospitalScreen extends StatefulWidget {
  final String requestId;
  const NavigateToHospitalScreen({super.key, required this.requestId});

  @override
  State<NavigateToHospitalScreen> createState() =>
      _NavigateToHospitalScreenState();
}

class _NavigateToHospitalScreenState
    extends State<NavigateToHospitalScreen> {
  final _firestoreService = FirestoreService();
  final _locationService = LocationService();
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  final _mapController = MapController();

  LatLng? _driverLocation;
  HospitalModel? _hospital;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  void _startTracking() {
    _locationService.startTracking(
      driverId: _uid,
      requestId: widget.requestId,
      onPosition: (Position pos) {
        if (!mounted) return;
        final newLoc = LatLng(pos.latitude, pos.longitude);
        setState(() => _driverLocation = newLoc);
        _mapController.move(newLoc, _mapController.camera.zoom);
      },
    );
  }

  Future<void> _completeRide() async {
    _locationService.stopTracking();
    await _firestoreService.completeRide(widget.requestId, _uid);
    if (mounted) context.go('/driver/ride-complete');
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
        title: const Text('Navigate to Hospital'),
        backgroundColor: AppColors.navy,
        leading: const SizedBox.shrink(),
      ),
      body: StreamBuilder<RescueRequestModel>(
        stream: _firestoreService.watchRequest(widget.requestId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child:
                    CircularProgressIndicator(color: AppColors.emergency));
          }
          final request = snapshot.data!;

          // Load hospital once when assignedHospitalId becomes available
          if (request.assignedHospitalId != null && _hospital == null) {
            _firestoreService
                .getHospital(request.assignedHospitalId!)
                .then((h) {
              if (!mounted || h == null) return;
              setState(() => _hospital = h);
              if (h.location != null) {
                _mapController.move(
                  LatLng(h.location!.latitude, h.location!.longitude),
                  13,
                );
              }
            });
          }

          final hospitalLatLng = _hospital?.location != null
              ? LatLng(
                  _hospital!.location!.latitude,
                  _hospital!.location!.longitude,
                )
              : null;

          final initialCenter = hospitalLatLng ??
              _driverLocation ??
              const LatLng(22.5726, 88.3639);

          return Column(
            children: [
              Expanded(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: initialCenter,
                    initialZoom: 13,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.tenminrescue.ten_min_res',
                    ),
                    MarkerLayer(
                      markers: [
                        // Hospital marker
                        if (hospitalLatLng != null)
                          Marker(
                            point: hospitalLatLng,
                            width: 48,
                            height: 48,
                            child: const Icon(
                              Icons.local_hospital_rounded,
                              color: AppColors.onlineGreen,
                              size: 44,
                            ),
                          ),
                        // Driver marker
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

              Container(
                padding: const EdgeInsets.all(20),
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_hospital != null) ...[
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.onlineGreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.local_hospital,
                                color: AppColors.onlineGreen),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_hospital!.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.navy,
                                        fontSize: 15)),
                                Text(_hospital!.address,
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ] else
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Waiting for hospital assignment...',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 14),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _hospital != null ? _completeRide : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emergency,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Arrived at Hospital',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
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
