import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:punyadaan/auth/login_screen.dart';
import 'package:punyadaan/home/donator_home_page.dart';
import 'package:punyadaan/home/donee_home_page.dart';
import 'package:punyadaan/auth/role_selection_screen.dart';
import 'package:punyadaan/admin/admin_dashboard_screen.dart';
import 'package:punyadaan/profile/deactivation_service.dart';

/// Listens to Firebase auth state and routes to the correct screen.
/// - user == null  →  LoginScreen
/// - user != null && email == admin  →  AdminDashboardScreen
/// - user != null && role set  →  DemoHomePage or DoneeHomePage
/// - user != null && no role  →  RoleSelectionScreen
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still waiting for the first auth event
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          final user = snapshot.data!;
          
          if (user.email == 'punyadaan5@gmail.com') {
            return const AdminDashboardScreen();
          }

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get(),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Colors.white,
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (roleSnapshot.hasData && roleSnapshot.data!.exists) {
                final data = roleSnapshot.data!.data() as Map<String, dynamic>?;
                if (data != null && data.containsKey('role')) {
                  // Fire-and-forget sync to automatically hydrate legacy user profiles for the Admin Dashboard
                  if (data['name'] == null || data['email'] == null) {
                    FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                      'name': user.displayName ?? 'Unknown',
                      'email': user.email ?? user.phoneNumber ?? 'Unknown',
                    }, SetOptions(merge: true));
                  }

                  // ── Deactivation startup check ──
                  // If account is already marked deactivated, sign out immediately.
                  final deactivationStatus =
                      data['deactivationStatus'] as String? ?? 'none';
                  if (deactivationStatus == 'deactivated') {
                    // Fire-and-forget sign-out; rebuild will route to LoginScreen.
                    DeactivationService.checkAndApplyDeactivation();
                    return const LoginScreen();
                  }

                  // If approved and timer has expired, check and apply deactivation.
                  if (deactivationStatus == 'approved') {
                    return FutureBuilder<bool>(
                      future: DeactivationService.checkAndApplyDeactivation(),
                      builder: (context, deactivSnap) {
                        if (deactivSnap.connectionState ==
                            ConnectionState.waiting) {
                          return const Scaffold(
                            backgroundColor: Colors.white,
                            body:
                                Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (deactivSnap.data == true) {
                          // Was just deactivated — route to login
                          return const LoginScreen();
                        }
                        // Timer hasn't expired yet, proceed normally
                        final role = data['role'];
                        return role == 'donee'
                            ? const DoneeHomePage()
                            : const DemoHomePage();
                      },
                    );
                  }

                  final role = data['role'];
                  if (role == 'donee') {
                    return const DoneeHomePage();
                  } else {
                    return const DemoHomePage();
                  }
                }
              }

              // No role found in Firestore -> show RoleSelectionScreen
              return const RoleSelectionScreen();
            },
          );
        }
        return const LoginScreen();
      },
    );
  }
}
