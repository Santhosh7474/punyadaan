import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'donee_create_event_screen.dart';
import 'donee_temple_tab.dart';
import 'donee_your_events_screen.dart';
import '../profile/donee_profile_screen.dart';

class DoneeHomePage extends StatefulWidget {
  const DoneeHomePage({super.key});

  @override
  State<DoneeHomePage> createState() => _DoneeHomePageState();
}

class _DoneeHomePageState extends State<DoneeHomePage> {
  int _currentNavIndex = 0;
  final double _navOpacity = 0.95;
  bool _isSubscribed = false;

  // ── Dynamic bottom nav tab (changes after org registration) ─────
  String _doneeTabLabel = 'Donee';
  IconData _doneeTabIcon = Icons.account_circle_outlined;
  IconData _doneeTabActiveIcon = Icons.account_circle_rounded;
  StreamSubscription<QuerySnapshot>? _orgSubscription;

  @override
  void initState() {
    super.initState();
    _checkSubscriptionStatus();
    _listenToOrganization();
  }

  Future<void> _checkSubscriptionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isSubscribed = prefs.getBool('donee_subscribed') ?? false;
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
          _doneeTabLabel = 'Donee';
          _doneeTabIcon = Icons.account_circle_outlined;
          _doneeTabActiveIcon = Icons.account_circle_rounded;
        });
      } else {
        final category =
            snap.docs.first.data()['category'] as String? ?? 'Temple';
        final info = _categoryInfo(category);
        setState(() {
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

  Future<void> _subscribe() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('donee_subscribed', true);
    setState(() {
      _isSubscribed = true;
      _currentNavIndex = 1; // Events tab
    });
  }

  void _showSubscriptionDialog() {
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
            Container(
              height: 4,
              width: 40,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.amber,
              size: 80,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unlock Extra Features',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  height: 1.5,
                ),
                children: [
                  TextSpan(text: 'Subscribe for '),
                  TextSpan(
                    text: '₹100 ',
                    style: TextStyle(decoration: TextDecoration.lineThrough),
                  ),
                  TextSpan(
                    text: '₹0 (For Free) ',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF24963F)),
                  ),
                  TextSpan(text: 'to create and manage events. Reach out to more donors easily!'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _subscribe();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Subscription Successful!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF24963F), // donator green
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Subscribe',
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        extendBody: true,
        floatingActionButton: _currentNavIndex == 1
            ? Padding(
                padding: const EdgeInsets.only(bottom: 96),
                child: FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          backgroundColor: const Color(0xFFF6F8FD),
                          appBar: AppBar(
                            title: const Text(
                              'Create Event',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                            ),
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            foregroundColor: Colors.black87,
                          ),
                          body: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFF6F8FD), Color(0xFFE9F0E6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const DoneeCreateEventScreen(),
                          ),
                        ),
                      ),
                    );
                  },
                  backgroundColor: const Color(0xFF24963F),
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  label: const Text('Create Event', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  elevation: 4,
                ),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
                  DoneeYourEventsScreen(),
                  DoneeProfileScreen(),
                ],
              ),
              // Floating Frosted Bottom Navigation Bar
              Positioned(
                bottom: 24,
                left: 20,
                right: 20,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutQuint,
                      height: 76,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: _navOpacity * 0.4),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.8),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                              if (_isSubscribed) {
                                setState(() => _currentNavIndex = 1);
                              } else {
                                _showSubscriptionDialog();
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
    const activeColor = Color(0xFF24963F); // Match donator green
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutQuint,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 20 : 12,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? activeColor : Colors.black87,
              size: 26,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutQuint,
              alignment: Alignment.centerLeft,
              child: isActive
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: activeColor,
                          letterSpacing: 0.2,
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
