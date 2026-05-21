import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/organization_model.dart';
import 'donee_register_temple_screen.dart';
import 'donee_temple_profile_screen.dart';

class DoneeTempleTab extends StatelessWidget {
  const DoneeTempleTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('User not logged in'));

    // Query ANY organization owned by this donee — not just 'Temple'
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('organizations')
          .where('doneeId', isEqualTo: user.uid)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF24963F)));
        }

        if (snapshot.hasError) {
          return Center(
              child: Text('Error loading data: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          // No org registered yet — show registration form
          return const DoneeRegisterTempleScreen();
        }

        final org = Organization.fromFirestore(snapshot.data!.docs.first);
        return DoneeTempleProfileScreen(organization: org);
      },
    );
  }
}
