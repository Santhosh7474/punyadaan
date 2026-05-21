import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class DeactivationService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Submits a deactivation request for the current user.
  /// [role] must be either 'donator' or 'donee'.
  static Future<void> requestDeactivation(String role) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final now = Timestamp.now();

    // Write to deactivation_requests collection
    await _firestore
        .collection('deactivation_requests')
        .doc(user.uid)
        .set({
      'uid': user.uid,
      'email': user.email ?? '',
      'displayName': user.displayName ?? 'User',
      'role': role,
      'status': 'pending',
      'requestedAt': now,
      'approvedAt': null,
      'deactivateAt': null,
      'adminNote': '',
    });

    // Update users document
    await _firestore.collection('users').doc(user.uid).set({
      'deactivationStatus': 'pending',
      'deactivateAt': null,
    }, SetOptions(merge: true));
  }

  /// Cancels a pending deactivation request (only if still pending).
  static Future<void> cancelDeactivationRequest() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('deactivation_requests')
        .doc(user.uid)
        .update({'status': 'cancelled'});

    await _firestore.collection('users').doc(user.uid).set({
      'deactivationStatus': 'none',
      'deactivateAt': null,
    }, SetOptions(merge: true));
  }

  /// Fetches the current user's deactivation status from Firestore.
  /// Returns one of: 'none', 'pending', 'approved', 'deactivated', 'rejected'.
  static Future<Map<String, dynamic>?> getDeactivationInfo() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore
        .collection('deactivation_requests')
        .doc(user.uid)
        .get();

    if (!doc.exists) return null;
    return doc.data();
  }

  /// Called at app startup (in AuthGate) to automatically deactivate
  /// accounts whose deactivateAt timestamp has passed.
  /// Returns true if the account was just deactivated (caller should sign out).
  static Future<bool> checkAndApplyDeactivation() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return false;

      final data = userDoc.data()!;
      final status = data['deactivationStatus'] as String? ?? 'none';

      if (status == 'approved') {
        final deactivateAt = data['deactivateAt'] as Timestamp?;
        if (deactivateAt != null &&
            deactivateAt.toDate().isBefore(DateTime.now())) {
          // Timer has expired — mark as deactivated
          await _firestore.collection('users').doc(user.uid).update({
            'deactivationStatus': 'deactivated',
          });
          await _firestore
              .collection('deactivation_requests')
              .doc(user.uid)
              .update({'status': 'deactivated'});

          // Sign the user out
          await GoogleSignIn().signOut();
          await _auth.signOut();
          return true;
        }
      }
    } catch (_) {}
    return false;
  }
}
