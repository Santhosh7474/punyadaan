// lib/services/permission_service.dart
//
// Requests every permission the app needs, one at a time, with a friendly
// rationale dialog shown BEFORE the system prompt so the user understands why.
// Uses shared_preferences to only run the full flow once (on first launch).
// Subsequent launches skip already-granted permissions silently.

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Internal model ─────────────────────────────────────────────────────
class _PermItem {
  const _PermItem({
    required this.permission,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.rationale,
  });

  final Permission permission;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String rationale;
}

// ── Service ────────────────────────────────────────────────────────────
class PermissionService {
  static const String _prefKey = 'permissions_requested_v1';

  // ── Public entry point ─────────────────────────────────────────────
  /// Call this from SplashScreen. Shows the permission flow only on first
  /// launch; subsequent runs silently request any that are still denied.
  static Future<void> requestAllPermissions(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyRan = prefs.getBool(_prefKey) ?? false;

    final permissions = _buildPermissionList();

    if (!alreadyRan) {
      if (!context.mounted) return;
      await _requestWithRationale(context, permissions);
      await prefs.setBool(_prefKey, true);
    } else {
      await _requestSilently(permissions);
    }
  }

  // ── Permission list ────────────────────────────────────────────────
  static List<_PermItem> _buildPermissionList() {
    return [
      _PermItem(
        permission: Permission.notification,
        icon: Icons.notifications_active_rounded,
        iconColor: const Color(0xFFFF6B35),
        title: 'Notifications',
        rationale:
            'PunyaDaan sends you real-time alerts when someone donates to your '
            'event, when a new event is nearby, and for important app updates. '
            'Allow notifications to stay connected.',
      ),
      _PermItem(
        permission: Permission.location,
        icon: Icons.location_on_rounded,
        iconColor: const Color(0xFF1565C0),
        title: 'Location',
        rationale:
            'Location helps PunyaDaan show donation events near you and '
            'auto-fill your address in your profile. '
            'Your location is never shared with other users.',
      ),
      _PermItem(
        permission: Permission.microphone,
        icon: Icons.mic_rounded,
        iconColor: const Color(0xFF6A1B9A),
        title: 'Microphone',
        rationale:
            'PunyaDaan uses your microphone for the voice search feature, '
            'so you can search for events or organisations hands-free.',
      ),
      _PermItem(
        permission: Permission.camera,
        icon: Icons.camera_alt_rounded,
        iconColor: const Color(0xFF2E7D32),
        title: 'Camera',
        rationale:
            'Camera access lets you scan QR codes to make donations instantly '
            'and take a new profile photo directly from the app.',
      ),
      _PermItem(
        permission: Permission.photos,
        icon: Icons.photo_library_rounded,
        iconColor: const Color(0xFFC62828),
        title: 'Photo Library',
        rationale:
            'PunyaDaan needs access to your photos to let you upload a '
            'profile picture or attach a registration certificate.',
      ),
    ];
  }

  // ── First-launch: show rationale then system dialog ────────────────
  static Future<void> _requestWithRationale(
    BuildContext context,
    List<_PermItem> items,
  ) async {
    for (final item in items) {
      if (!context.mounted) return;

      final current = await item.permission.status;
      if (current.isGranted) continue;
      if (current.isPermanentlyDenied) continue;

      if (!context.mounted) return;
      final proceed = await _showRationaleDialog(context, item);
      if (!context.mounted) return;
      if (!proceed) continue;

      await item.permission.request();

      if (!context.mounted) return;

      await Future.delayed(const Duration(milliseconds: 400));

      if (!context.mounted) return;
    }
  }

  // ── Subsequent launches: silent re-request ─────────────────────────
  static Future<void> _requestSilently(List<_PermItem> items) async {
    for (final item in items) {
      final status = await item.permission.status;
      if (status.isDenied) {
        await item.permission.request();
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  // ── Rationale dialog ───────────────────────────────────────────────
  static Future<bool> _showRationaleDialog(
    BuildContext context,
    _PermItem item,
  ) async {
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Permission',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder: (ctx, anim, _, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon badge
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: item.iconColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child:
                          Icon(item.icon, color: item.iconColor, size: 36),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Rationale text
                    Text(
                      item.rationale,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text(
                              'Not Now',
                              style: TextStyle(
                                color: Colors.black45,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: item.iconColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text(
                              'Allow',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    return result ?? false;
  }
}
