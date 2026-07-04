import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'donee_temple_tab.dart';
import 'donee_your_events_screen.dart';
import '../profile/donee_profile_screen.dart';
import '../services/fcm_service.dart';

class DoneeHomePage extends StatefulWidget {
  const DoneeHomePage({super.key});

  @override
  State<DoneeHomePage> createState() => _DoneeHomePageState();
}

class _DoneeHomePageState extends State<DoneeHomePage> {
  int _currentNavIndex = 0;
  // Tracks the donee's organization approval status
  String _orgStatus = 'none'; // 'none' | 'pending' | 'approved'

  // ── Dynamic bottom nav tab (changes after org registration) ─────
  String _doneeTabLabel = 'Donee';
  IconData _doneeTabIcon = Icons.account_circle_outlined;
  IconData _doneeTabActiveIcon = Icons.account_circle_rounded;
  StreamSubscription<QuerySnapshot>? _orgSubscription;

  @override
  void initState() {
    super.initState();
    _listenToOrganization();

    // Initialize FCM and request permissions after login
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FCMService.init();
      }
    });
  }

  // ── Listen for the donee's registered org to update bottom nav ──
  void _listenToOrganization() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _orgSubscription = FirebaseFirestore.instance
        .collection('organizations')
        .where('doneeId', isEqualTo: user.uid)
        .limit(1)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      if (snap.docs.isEmpty) {
        setState(() {
          _orgStatus = 'none';
          _doneeTabLabel = 'Donee';
          _doneeTabIcon = Icons.account_circle_outlined;
          _doneeTabActiveIcon = Icons.account_circle_rounded;
        });
      } else {
        final data = snap.docs.first.data();
        final status = data['status'] as String? ?? 'pending';
        final category = data['category'] as String? ?? 'Temple';
        final info = _categoryInfo(category);
        setState(() {
          _orgStatus = status;
          _doneeTabLabel = info.label;
          _doneeTabIcon = info.icon;
          _doneeTabActiveIcon = info.activeIcon;
        });
      }
    });
  }

  /// Maps Firestore category → display label + icons
  ({String label, IconData icon, IconData activeIcon}) _categoryInfo(
      String category) {
    switch (category) {
      case 'Temple':
        return (
          label: 'Religious Place',
          icon: Icons.temple_hindu_outlined,
          activeIcon: Icons.temple_hindu_rounded,
        );
      case 'Gaushala':
        return (
          label: 'Gaushala',
          icon: Icons.pets_outlined,
          activeIcon: Icons.pets_rounded,
        );
      case 'Charity':
        return (
          label: 'Charity Org',
          icon: Icons.volunteer_activism_outlined,
          activeIcon: Icons.volunteer_activism_rounded,
        );
      case 'Yogdaan':
        return (
          label: 'Yogdaan',
          icon: Icons.self_improvement_outlined,
          activeIcon: Icons.self_improvement_rounded,
        );
      default:
        return (
          label: category,
          icon: Icons.business_outlined,
          activeIcon: Icons.business_rounded,
        );
    }
  }

  @override
  void dispose() {
    _orgSubscription?.cancel();
    super.dispose();
  }

  // ── Show dialog when donee has no registered organization ──────
  void _showNoOrgDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                height: 4,
                width: 40,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Icon(
              Icons.account_balance_rounded,
              color: Color(0xFFB71C1C),
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Register Your Organization First',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'You need to register and get your organization approved before you can create events.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _currentNavIndex = 0); // Go to Donee tab (profile/register)
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB71C1C),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Go to Register',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Show dialog when org is registered but pending admin approval ─
  void _showOrgPendingDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                height: 4,
                width: 40,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Icon(
              Icons.hourglass_top_rounded,
              color: Color(0xFFF0A500),
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Approval Pending',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your organization is awaiting admin approval. The Events page will be unlocked once approved.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Color(0xFFF0A500), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'OK, Got It',
                style: TextStyle(
                  color: Color(0xFFF0A500),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        extendBody: true,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF6F8FD), Color(0xFFE9F0E6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              IndexedStack(
                index: _currentNavIndex,
                children: const [
                  DoneeTempleTab(),
                  DoneeYourEventsScreen(showCreateButton: true),
                  DoneeProfileScreen(),
                ],
              ),
              // Floating Crimson Bottom Navigation Bar
              Positioned(
                bottom: 24,
                left: 20,
                right: 20,
                child: Container(
                  height: 68,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB71C1C),
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFB71C1C).withValues(alpha: 0.45),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _BottomNavItem(
                        icon: _doneeTabIcon,
                        activeIcon: _doneeTabActiveIcon,
                        label: _doneeTabLabel,
                        isActive: _currentNavIndex == 0,
                        onTap: () => setState(() => _currentNavIndex = 0),
                      ),
                      _BottomNavItem(
                        icon: Icons.event_note_outlined,
                        activeIcon: Icons.event_note_rounded,
                        label: 'Events',
                        isActive: _currentNavIndex == 1,
                        onTap: () {
                          if (_orgStatus == 'approved') {
                            setState(() => _currentNavIndex = 1);
                          } else if (_orgStatus == 'pending') {
                            _showOrgPendingDialog();
                          } else {
                            _showNoOrgDialog();
                          }
                        },
                      ),
                      _BottomNavItem(
                        icon: Icons.person_outline_rounded,
                        activeIcon: Icons.person_rounded,
                        label: 'Profile',
                        isActive: _currentNavIndex == 2,
                        onTap: () => setState(() => _currentNavIndex = 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 18 : 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          // Active pill: Primary Gold; inactive: transparent
          color: isActive ? const Color(0xFFF0A500) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFFF0A500).withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : icon,
                color: Colors.white,
                size: 26),
            AnimatedSize(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              alignment: Alignment.centerLeft,
              child: isActive
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
