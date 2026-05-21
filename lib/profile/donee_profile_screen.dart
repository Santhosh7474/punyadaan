import 'dart:convert';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'deactivation_service.dart';
import 'donee_edit_profile_screen.dart';

class DoneeProfileScreen extends StatefulWidget {
  const DoneeProfileScreen({super.key});

  @override
  State<DoneeProfileScreen> createState() => _DoneeProfileScreenState();
}

class _DoneeProfileScreenState extends State<DoneeProfileScreen> {
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  // Deactivation state
  String _deactivationStatus = 'none';
  DateTime? _deactivateAt;
  bool _isDeactivating = false;

  @override
  void initState() {
    super.initState();
    _loadDeactivationStatus();
  }

  Future<void> _loadDeactivationStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!doc.exists || !mounted) return;
    final data = doc.data()!;
    setState(() {
      _deactivationStatus = data['deactivationStatus'] as String? ?? 'none';
      final ts = data['deactivateAt'] as Timestamp?;
      _deactivateAt = ts?.toDate();
    });
  }

  void _confirmSignOut(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 32),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Sign Out?',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Are you sure you want to log out?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.black54,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await GoogleSignIn().signOut();
                                  await FirebaseAuth.instance.signOut();
                                  if (context.mounted) {
                                    Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Deactivation helpers ──────────────────────────────────────────
  Future<void> _showDeactivateDialog() async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_off_rounded,
                            color: Color(0xFFFF6B35),
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Deactivate Account?',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Your request will be sent to the admin for review. If approved, your account will be deactivated within 10–15 days.\n\nYou can re-register with the same email afterwards and choose your role freely.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFFF6B35).withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  color: Color(0xFFFF6B35), size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'This action sends a request — your account remains active until admin approval.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFCC4400),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                child: const Text('Cancel',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black54)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: StatefulBuilder(
                                builder: (_, setBtn) => ElevatedButton(
                                  onPressed: _isDeactivating
                                      ? null
                                      : () async {
                                          setBtn(() => _isDeactivating = true);
                                          try {
                                            await DeactivationService
                                                .requestDeactivation('donee');
                                            if (mounted) {
                                              Navigator.pop(ctx);
                                              setState(() =>
                                                  _deactivationStatus = 'pending');
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                content: Text(
                                                    'Deactivation request sent to admin.'),
                                                backgroundColor:
                                                    Color(0xFFFF6B35),
                                              ));
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                      content: Text('Error: $e')));
                                            }
                                          } finally {
                                            if (mounted) {
                                              setState(() =>
                                                  _isDeactivating = false);
                                            }
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF6B35),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14)),
                                  ),
                                  child: _isDeactivating
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              color: Colors.white, strokeWidth: 2))
                                      : const Text('Send Request',
                                          style: TextStyle(fontWeight: FontWeight.w700)),
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeactivationBanner() {
    if (_deactivationStatus == 'none' || _deactivationStatus == 'rejected') {
      return const SizedBox.shrink();
    }
    final bool isApproved = _deactivationStatus == 'approved';
    final color = isApproved ? const Color(0xFFD32F2F) : const Color(0xFFFF6B35);
    final bgColor = isApproved
        ? const Color(0xFFD32F2F).withValues(alpha: 0.08)
        : const Color(0xFFFF6B35).withValues(alpha: 0.08);
    final borderColor = isApproved
        ? const Color(0xFFD32F2F).withValues(alpha: 0.3)
        : const Color(0xFFFF6B35).withValues(alpha: 0.3);
    String message;
    IconData icon;
    if (isApproved && _deactivateAt != null) {
      final d = _deactivateAt!;
      message =
          'Account will be deactivated on ${d.day}/${d.month}/${d.year}. You may re-register after that.';
      icon = Icons.warning_amber_rounded;
    } else if (isApproved) {
      message = 'Deactivation approved. Your account will be deactivated soon.';
      icon = Icons.warning_amber_rounded;
    } else {
      message = 'Deactivation request is pending admin approval.';
      icon = Icons.hourglass_top_rounded;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                color: color,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
          if (_deactivationStatus == 'pending')
            GestureDetector(
              onTap: () async {
                await DeactivationService.cancelDeactivationRequest();
                if (mounted) {
                  setState(() => _deactivationStatus = 'none');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Deactivation request cancelled.')),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Cancel',
                    style: TextStyle(
                        fontSize: 11, color: color, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image == null) return;

      setState(() {
        _isUploading = true;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isUploading = false);
        return;
      }

      final bytes = await image.readAsBytes();
      
      if (bytes.isEmpty) {
        throw Exception("Selected image is empty.");
      }

      // Upload to Cloudinary via REST API
      final cloudName = 'dotlyaqsr';
      final apiKey = '594354471714585';
      final apiSecret = 'teR8IfY90hth1VpWge_9Bhoi4k4';
      
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final paramsToSign = 'folder=profile_images&public_id=${user.uid}&timestamp=$timestamp$apiSecret';
      final signature = sha1.convert(utf8.encode(paramsToSign)).toString();

      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['api_key'] = apiKey
        ..fields['timestamp'] = timestamp.toString()
        ..fields['signature'] = signature
        ..fields['folder'] = 'profile_images'
        ..fields['public_id'] = user.uid
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: '${user.uid}.jpg'));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      
      if (response.statusCode != 200) {
        throw Exception("Cloudinary upload failed: $responseData");
      }
      
      final jsonMap = json.decode(responseData);
      final downloadUrl = jsonMap['secure_url'];

      // Update Firebase Auth profile
      await user.updatePhotoURL(downloadUrl);
      
      // Force reload user to get updated data immediately
      await user.reload();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _showProfileOptions(BuildContext context, String? photoUrl) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (photoUrl != null)
                  ListTile(
                    leading: const Icon(Icons.person_search_rounded, color: Colors.black87),
                    title: const Text('View profile', style: TextStyle(fontWeight: FontWeight.w500)),
                    onTap: () {
                      Navigator.pop(context);
                      _viewProfilePicture(context, photoUrl);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: Colors.black87),
                  title: const Text('Upload from gallery', style: TextStyle(fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadImage();
                  },
                ),
                if (photoUrl != null)
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                    title: const Text('Remove photo', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.red)),
                    onTap: () {
                      Navigator.pop(context);
                      _removePhoto();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _viewProfilePicture(BuildContext context, String photoUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: Image.network(photoUrl, fit: BoxFit.contain),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removePhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    setState(() => _isUploading = true);
    try {
      final cloudName = 'dotlyaqsr';
      final apiKey = '594354471714585';
      final apiSecret = 'teR8IfY90hth1VpWge_9Bhoi4k4';
      
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final publicId = 'profile_images/${user.uid}';
      
      final paramsToSign = 'public_id=$publicId&timestamp=$timestamp$apiSecret';
      final signature = sha1.convert(utf8.encode(paramsToSign)).toString();

      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/destroy');
      final response = await http.post(uri, body: {
        'public_id': publicId,
        'api_key': apiKey,
        'timestamp': timestamp.toString(),
        'signature': signature,
      });

      if (response.statusCode != 200) {
        debugPrint('Cloudinary destroy failed: ${response.body}');
      }

      await user.updatePhotoURL(null);
      await user.reload();
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Failed to remove photo: $e')),
         );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? 'User Name';
    final email = user?.email ?? 'username@example.com';
    final photoUrl = user?.photoURL;

    return SingleChildScrollView(
        padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 120),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // No App Bar since this is a tab content
              // Profile Image
              GestureDetector(
                onTap: () => _showProfileOptions(context, photoUrl),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                       width: 140,
                       height: 140,
                       decoration: BoxDecoration(
                         color: Colors.grey.shade200,
                         shape: BoxShape.circle,
                         border: Border.all(color: Colors.white, width: 4),
                         boxShadow: [
                           BoxShadow(
                             color: Colors.black.withValues(alpha: 0.05),
                             blurRadius: 10,
                             offset: const Offset(0, 5),
                           ),
                         ],
                         image: photoUrl != null
                             ? DecorationImage(
                                 image: NetworkImage(photoUrl),
                                 fit: BoxFit.cover,
                               )
                             : null,
                       ),
                       child: photoUrl == null
                           ? const Icon(
                               Icons.account_circle,
                               size: 140, // Match container size
                               color: Colors.black87,
                             )
                           : null,
                    ),
                    if (_isUploading)
                      Container(
                        width: 140,
                        height: 140,
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                email,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),

              // ── Deactivation status banner ──
              _buildDeactivationBanner(),

              // Settings Label
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // Settings Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _ProfileMenuItem(
                      icon: Icons.edit_rounded,
                      title: 'Edit Profile',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DoneeEditProfileScreen(),
                        ),
                      ),
                    ),
                    _ProfileMenuItem(
                      icon: Icons.contrast_rounded,
                      title: 'Theme',
                      onTap: () {},
                    ),
                    _ProfileMenuItem(
                      icon: Icons.policy_outlined,
                      title: 'Policies',
                      onTap: () {},
                    ),
                    _ProfileMenuItem(
                      icon: Icons.article_outlined,
                      title: 'Terms and Conditions',
                      onTap: () {},
                    ),
                    _ProfileMenuItem(
                      icon: Icons.info_outline_rounded,
                      title: 'About Us',
                      onTap: () {},
                    ),
                    _ProfileMenuItem(
                      icon: Icons.help_outline_rounded,
                      title: 'Support / Help',
                      onTap: () {},
                    ),
                    // Deactivate Account — shown only if not already requested
                    if (_deactivationStatus == 'none' || _deactivationStatus == 'rejected') ...[
                      const Divider(height: 1),
                      _DeactivateMenuItem(onTap: _showDeactivateDialog),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Log Out Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => _confirmSignOut(context),
                  icon: const Icon(Icons.logout_rounded, color: Colors.black87),
                  label: const Text(
                    'Log Out',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFDC5C5), // Soft red/pink log out
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Colors.black87),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.black87,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Deactivate Account Menu Item ───────────────────────────────────
class _DeactivateMenuItem extends StatelessWidget {
  const _DeactivateMenuItem({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.person_off_rounded,
                  size: 18, color: Color(0xFFFF6B35)),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Deactivate Account',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFF6B35),
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: Color(0xFFFF6B35)),
          ],
        ),
      ),
    );
  }
}
