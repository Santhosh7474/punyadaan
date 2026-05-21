import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  static const _logoAsset = 'assets/login/Logo.png';
  static const _appNameAsset = 'assets/login/App name.png';
  static const _fourIconsAsset = 'assets/login/4 category icons.png';
  static const _trustBadgesAsset = 'assets/login/3 trust badges.png';
  static const _bottomIllustrationAsset =
      'assets/login/Bottom illustration.png';

  bool _isLoading = false;

  Future<void> _selectRole(String role) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
            'role': role,
            'name': user.displayName ?? 'Unknown',
            'email': user.email ?? user.phoneNumber ?? 'Unknown',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 4));
      // Once written, AuthGate which listens to auth changes won't re-trigger automatically
      // since role is in firestore. We need a way to let AuthGate know or we just navigate.
      // Wait, AuthGate uses FutureBuilder on Firestore. If we call set(), we can just pop or
      // replace route to Home, but since AuthGate is the root handler for /auth, we can simply
      // reload the app or navigate to the correct home page directly and remove back stack.
      if (!mounted) return;
      if (role == 'donator') {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/home', (route) => false);
      } else {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/doneeHome', (route) => false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving role: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const olive = Color(0xFF8B8A2E);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F2),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          const SizedBox(height: 28),
                          Image.asset(
                            _logoAsset,
                            height: 120,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  height: 120,
                                  width: 120,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.image_not_supported_outlined,
                                  ),
                                ),
                          ),
                          const SizedBox(height: 10),
                          Image.asset(
                            _appNameAsset,
                            height: 52,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Text(
                              'PunyaDaan',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(height: 48),

                          // Role selection blocks
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: _RoleCard(
                                    title: 'Donator',
                                    color: olive,
                                    onTap: () => _selectRole('donator'),
                                    imageAsset: 'assets/role/man.png',
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _RoleCard(
                                    title: 'Donee',
                                    color: olive,
                                    onTap: () => _selectRole('donee'),
                                    imageAsset: 'assets/role/woman.png',
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // 4 category icons row
                          Image.asset(
                            _fourIconsAsset,
                            width: double.infinity,
                            fit: BoxFit.fitWidth,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  height: 80,
                                  width: double.infinity,
                                  color: Colors.black12,
                                  alignment: Alignment.center,
                                  child: const Text(
                                    '4 category icons placeholder',
                                  ),
                                ),
                          ),

                          const SizedBox(height: 24),

                          // Trust badges
                          SizedBox(
                            height: 64,
                            child: Image.asset(
                              _trustBadgesAsset,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox.shrink(),
                            ),
                          ),

                          const Spacer(),

                          // Bottom Illustration
                          Image.asset(
                            _bottomIllustrationAsset,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.fitWidth,
                            alignment: Alignment.bottomCenter,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
                          ),
                        ],
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: IconButton(
                          icon: const Icon(Icons.logout, color: Colors.black54),
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                          },
                        ),
                      ),
                      if (_isLoading)
                        Container(
                          color: Colors.black.withValues(alpha: 0.3),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.color,
    required this.onTap,
    required this.imageAsset,
  });

  final String title;
  final Color color;
  final VoidCallback onTap;
  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // The actual illustration (Man/Lady)
        Image.asset(
          imageAsset,
          height: 160,
          fit: BoxFit.contain,
          alignment: Alignment.bottomCenter,
          errorBuilder: (context, error, stackTrace) => Container(
            height: 160,
            alignment: Alignment.center,
            child: const Icon(Icons.person, size: 64, color: Colors.grey),
          ),
        ),
        // The selection button
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(30), // Stadium shape
            ),
            alignment: Alignment.center,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
