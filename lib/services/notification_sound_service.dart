// lib/services/notification_sound_service.dart
//
// Plays bell_sound.mp3 (with .mpeg as fallback) when a notification arrives,
// but ONLY if the user has notifications enabled in their Firestore profile.
//
// Usage:
//   await NotificationSoundService.playIfEnabled();
//
// Call this wherever a notification event is received in the app
// (e.g. from a Firestore stream listener, FCM onMessage, etc.)

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationSoundService {
  // Single shared AudioPlayer instance — reused across calls
  static final AudioPlayer _player = AudioPlayer();

  // ── Primary public method ──────────────────────────────────────────
  /// Checks Firestore for the current user's preferences:
  /// Both `notificationsEnabled` and `bellSoundEnabled` must be true.
  /// If true, plays bell_sound.mp3 (falls back to .mpeg if mp3 fails).
  static Future<void> playIfEnabled() async {
    final enabled = await _isBellSoundEnabled();
    if (!enabled) return;
    await _playBellSound();
  }

  // ── Check Firestore preference ─────────────────────────────────────
  static Future<bool> _isBellSoundEnabled() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Check both collections: donors use 'users', donees use 'donee_profiles'
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          final notif = data['notificationsEnabled'] as bool? ?? true;
          final bell = data['bellSoundEnabled'] as bool? ?? true;
          return notif && bell;
        }
      }

      // Try donee_profiles as fallback
      final doneeDoc = await FirebaseFirestore.instance
          .collection('donee_profiles')
          .doc(user.uid)
          .get();

      if (doneeDoc.exists) {
        final data = doneeDoc.data();
        if (data != null) {
          final notif = data['notificationsEnabled'] as bool? ?? true;
          final bell = data['bellSoundEnabled'] as bool? ?? true;
          return notif && bell;
        }
      }

      // Default: enabled if no preference saved yet
      return true;
    } catch (_) {
      // If any error, default to enabled so sound is not silently broken
      return true;
    }
  }

  // ── Play the bell sound ────────────────────────────────────────────
  static Future<void> _playBellSound() async {
    try {
      // Stop any currently playing sound first
      await _player.stop();

      // Try .mp3 first
      await _player.play(AssetSource('bell_sound.mp3'));
    } catch (_) {
      // Fallback to .mpeg if .mp3 fails
      try {
        await _player.stop();
        await _player.play(AssetSource('bell_sound.mpeg'));
      } catch (_) {
        // Silently ignore — sound failure must never crash the app
      }
    }
  }

  // ── Play directly (no Firestore check) ────────────────────────────
  /// Use this for testing or when you already know notifications are enabled.
  static Future<void> playDirect() async {
    await _playBellSound();
  }

  // ── Dispose ────────────────────────────────────────────────────────
  /// Call when the app is permanently closing (optional — OS will clean up).
  static Future<void> dispose() async {
    await _player.dispose();
  }
}
