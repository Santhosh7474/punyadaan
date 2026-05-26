// lib/services/fcm_service.dart
//
// Centralizes all Firebase Cloud Messaging logic:
//   • Requests notification permission
//   • Retrieves and saves the FCM token to Firestore (users/{uid}.fcmToken)
//   • Refreshes token when it rotates
//   • Handles foreground messages → saves to Firestore + plays bell sound
//   • Handles background/terminated tap → can be extended for routing

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'notification_sound_service.dart';

/// Top-level handler for background/terminated messages (must be top-level).
/// Called by FCM when the app is in the background or closed.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized by main.dart before this runs.
  debugPrint('FCM [background]: ${message.notification?.title}');
  // Note: Cannot play audio here (no audio context). The notification tray
  // already shows the message via FCM's built-in display.
}

class FCMService {
  FCMService._();

  static final _messaging = FirebaseMessaging.instance;

  /// Call this once after the user has logged in (e.g. inside DemoHomePage.initState).
  static Future<void> init() async {
    // 1. Request permission (Android 13+ / iOS)
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // 2. Get token and save to Firestore
    await _saveToken();

    // 3. Refresh token automatically whenever FCM rotates it
    _messaging.onTokenRefresh.listen(_persistToken);

    // 4. Handle messages while app is in FOREGROUND
    FirebaseMessaging.onMessage.listen(_handleForeground);

    // 5. Handle notification tap when app is in BACKGROUND (not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // 6. Handle notification tap when app was TERMINATED
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      _handleTap(initial);
    }
  }

  // ── Token helpers ────────────────────────────────────────────────────

  /// Fetches the current FCM token, prints it, and saves to Firestore.
  static Future<String?> _saveToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('╔══════════════════════════════════════════════════════╗');
        debugPrint('║  FCM TOKEN (copy this to test notifications)         ║');
        debugPrint('║  $token');
        debugPrint('╚══════════════════════════════════════════════════════╝');
        await _persistToken(token);
      }
      return token;
    } catch (e) {
      debugPrint('FCMService: failed to get token: $e');
      return null;
    }
  }

  static Future<void> _persistToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FCMService: failed to persist token: $e');
    }
  }

  // ── Message handlers ─────────────────────────────────────────────────

  /// Foreground message: save to Firestore subcollection + play bell sound.
  static Future<void> _handleForeground(RemoteMessage message) async {
    debugPrint('FCM [foreground]: ${message.notification?.title}');

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Save notification to Firestore so NotificationsScreen picks it up
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .add({
            'title': message.notification?.title ?? 'Notification',
            'body': message.notification?.body ?? '',
            'type': message.data['type'] ?? 'general',
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('FCMService: failed to save notification: $e');
    }

    // Play bell sound if user has it enabled
    await NotificationSoundService.playIfEnabled();
  }

  /// Called when user taps a notification to open the app.
  static void _handleTap(RemoteMessage message) {
    debugPrint('FCM [tap]: ${message.notification?.title}');
  }

  // ── Public utility ───────────────────────────────────────────────────

  /// Returns the current device FCM token (useful for printing/sharing).
  static Future<String?> getToken() => _messaging.getToken();
}
