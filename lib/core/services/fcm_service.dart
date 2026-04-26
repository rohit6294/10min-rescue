import 'dart:async';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';

/// Local in-app SOS alert service.
///
/// We deliberately do NOT use FCM / Cloud Messaging here because that
/// requires Cloud Functions, which require the Blaze (paid) Firebase
/// plan.  Instead, the driver app stays subscribed to the Firestore
/// `sos_requests` stream and we fire a high-priority local notification
/// whenever a new pending SOS arrives — full sound, vibration, and
/// (on Android) a heads-up notification that wakes the screen.
///
/// Limitation vs. real FCM: the app must be running (foreground OR
/// recently backgrounded).  If the OS hard-kills the process, alerts
/// pause until the driver next opens the app.  This is fine while a
/// driver is actively on duty.
///
/// File name kept as `fcm_service.dart` to avoid breaking imports.  The
/// public class is still `FcmService` for the same reason.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'sos_emergency';
  static const _channelName = '🚨 Emergency SOS';
  static const _channelDesc =
      'Critical alerts for new ambulance & rescue requests';

  bool _initialized = false;
  final Set<String> _seenSosIds = <String>{};

  /// Idempotent — call once at app boot from main().
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload;
        if (payload != null && payload.isNotEmpty) _routeFromPayload(payload);
      },
    );

    if (Platform.isAndroid) {
      // Ask the OS for the POST_NOTIFICATIONS permission (Android 13+)
      // and create the high-importance channel up front.
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// Compatibility shim — the driver_home_screen calls this on
  /// startup.  We have no FCM token to register but we still warm up
  /// the notification permission flow so the driver is asked once.
  Future<void> registerCurrentDriverToken() async {
    if (!_initialized) await init();
  }

  /// Fire a heads-up local notification for a brand-new SOS request.
  ///
  /// `sosId` is used for de-duplication (the Firestore stream will
  /// re-emit the same list multiple times — we only want to alert
  /// once per SOS).
  Future<void> notifyNewSos({
    required String sosId,
    String? patientName,
    String? phone,
    String? emergencyType,
    double? distanceKm,
  }) async {
    if (!_initialized) await init();
    if (_seenSosIds.contains(sosId)) return;
    _seenSosIds.add(sosId);

    final titleBits = ['🚨 EMERGENCY SOS'];
    if (emergencyType != null && emergencyType.isNotEmpty) {
      titleBits.add('· $emergencyType');
    }

    final bodyBits = <String>[];
    if (patientName != null && patientName.isNotEmpty) {
      bodyBits.add(patientName);
    }
    if (phone != null && phone.isNotEmpty) bodyBits.add(phone);
    if (distanceKm != null) {
      bodyBits.add('${distanceKm.toStringAsFixed(1)} km away');
    }
    final body = bodyBits.isEmpty
        ? 'Tap to view request details'
        : bodyBits.join(' · ');

    await _local.show(
      sosId.hashCode & 0x7fffffff,
      titleBits.join(' '),
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.call,
          color: const Color.fromARGB(0xFF, 0xFF, 0x3B, 0x3B),
          ledColor: const Color.fromARGB(0xFF, 0xFF, 0x3B, 0x3B),
          ledOnMs: 800,
          ledOffMs: 500,
          enableVibration: true,
          playSound: true,
          autoCancel: true,
          ticker: 'New SOS',
        ),
        iOS: const DarwinNotificationDetails(
            presentSound: true, presentAlert: true),
      ),
      payload: 'sos:$sosId',
    );
    debugPrint('FcmService: alert fired for SOS $sosId');
  }

  /// Same idea but for an incoming rescue_requests entry.
  Future<void> notifyNewRescueRequest({
    required String requestId,
    String? patientName,
    String? emergencyType,
  }) async {
    if (!_initialized) await init();
    if (_seenSosIds.contains('req:$requestId')) return;
    _seenSosIds.add('req:$requestId');

    final body = <String>[
      if (patientName != null && patientName.isNotEmpty) patientName,
      if (emergencyType != null && emergencyType.isNotEmpty) emergencyType,
    ].join(' · ');

    await _local.show(
      requestId.hashCode & 0x7fffffff,
      '🚑 Incoming Rescue Request',
      body.isEmpty ? 'Tap to view' : body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
          playSound: true,
          autoCancel: true,
        ),
        iOS: const DarwinNotificationDetails(
            presentSound: true, presentAlert: true),
      ),
      payload: 'rescue:$requestId',
    );
  }

  /// Forget previously-seen IDs (e.g. when driver toggles offline).
  void resetSeen() => _seenSosIds.clear();

  void _routeFromPayload(String payload) {
    final parts = payload.split(':');
    if (parts.length != 2) return;
    final type = parts[0], id = parts[1];
    final ctx = AppRouter.router.routerDelegate.navigatorKey.currentContext;
    if (ctx == null) return;
    switch (type) {
      case 'sos':
        ctx.go('/driver/sos/$id');
        break;
      case 'rescue':
        ctx.go('/driver/request/$id');
        break;
    }
  }
}
