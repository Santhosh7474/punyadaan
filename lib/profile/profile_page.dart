import 'dart:convert';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import '../admin/add_organization_screen.dart';
import 'deactivation_service.dart';
import 'edit_profile_screen.dart';
import 'payment_settings_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isUploading = false;
  bool _isPublic = false;
  Map<String, dynamic> _userData = {};
  final ImagePicker _picker = ImagePicker();

  // Deactivation state
  String _deactivationStatus = 'none'; // none | pending | approved | deactivated | rejected
  DateTime? _deactivateAt;
  bool _isDeactivating = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadDeactivationStatus();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists && mounted) {
      setState(() {
        _userData = doc.data()!;
        _isPublic = _userData['isPublic'] ?? false;
      });
    }
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

  /// Returns a 0.0–1.0 completion percentage based on filled profile fields.
  double _calcCompletion() {
    final user = FirebaseAuth.instance.currentUser;
    int filled = 0;
    const total = 7;

    // 1. Display name / first name
    final firstName = (_userData['firstName'] as String? ?? '').trim();
    final displayName = (user?.displayName ?? '').trim();
    if (firstName.isNotEmpty || displayName.isNotEmpty) filled++;

    // 2. Last name
    if ((_userData['lastName'] as String? ?? '').trim().isNotEmpty) filled++;

    // 3. Email
    final email = (user?.email ?? _userData['email'] as String? ?? '').trim();
    if (email.isNotEmpty) filled++;

    // 4. Location
    if ((_userData['location'] as String? ?? '').trim().isNotEmpty) filled++;

    // 5. Aadhar
    if ((_userData['aadharNumber'] as String? ?? '').trim().isNotEmpty) filled++;

    // 6. PAN
    if ((_userData['panNumber'] as String? ?? '').trim().isNotEmpty) filled++;

    // 7. Photo
    if ((user?.photoURL ?? '').isNotEmpty) filled++;

    return filled / total;
  }

  Future<void> _togglePrivacy(bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() => _isPublic = value);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'isPublic': value,
        if (!value) 'punyaScore': FieldValue.increment(0),
      }, SetOptions(merge: true));
    }
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
                            color: const Color(0xFFB71C1C).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_off_rounded,
                            color: Color(0xFFB71C1C),
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Deactivate Account?',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB71C1C),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Your request will be sent to the admin for review. If approved, your account will be deactivated within 10–15 days.\n\nYou can re-register with the same email afterwards and choose your role freely.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF5C4033),
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB71C1C).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFB71C1C).withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  color: Color(0xFFB71C1C), size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'This action sends a request — your account remains active until admin approval.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFB71C1C),
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
                                        color: Color(0xFF5C4033))),
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
                                          final messenger =
                                              ScaffoldMessenger.of(context);
                                          try {
                                            await DeactivationService
                                                .requestDeactivation('donator');
                                            if (ctx.mounted) {
                                              Navigator.pop(ctx);
                                            }
                                            if (mounted) {
                                              setState(() =>
                                                  _deactivationStatus = 'pending');
                                              messenger.showSnackBar(const SnackBar(
                                                content: Text(
                                                    'Deactivation request sent to admin.'),
                                                backgroundColor:
                                                    Color(0xFFB71C1C),
                                              ));
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              messenger.showSnackBar(SnackBar(
                                                  content: Text(
                                                      'Error: $e')));
                                            }
                                          } finally {
                                            if (mounted) {
                                              setState(() =>
                                                  _isDeactivating = false);
                                            }
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFB71C1C),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                  ),
                                  child: _isDeactivating
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2))
                                      : const Text('Send Request',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700)),
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
    final color = isApproved ? const Color(0xFFD32F2F) : const Color(0xFFB71C1C);
    final bgColor = isApproved
        ? const Color(0xFFD32F2F).withValues(alpha: 0.08)
        : const Color(0xFFB71C1C).withValues(alpha: 0.08);
    final borderColor = isApproved
        ? const Color(0xFFD32F2F).withValues(alpha: 0.3)
        : const Color(0xFFB71C1C).withValues(alpha: 0.3);

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
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
                          child: const Icon(Icons.logout_rounded, color: Color(0xFFB71C1C), size: 32),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Log Out?',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB71C1C),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Are you sure you want to log out?',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, color: Color(0xFF5C4033), height: 1.4),
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
                                child: const Text('Cancel',
                                    style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF5C4033))),
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
                                    Navigator.of(context)
                                        .pushNamedAndRemoveUntil('/auth', (route) => false);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFB71C1C),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w700)),
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

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image == null) return;

      // Crop step — user can crop/rotate before upload
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Photo',
            toolbarColor: const Color(0xFFB71C1C),
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: const Color(0xFFF0A500),
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop Profile Photo',
            aspectRatioLockEnabled: false,
          ),
        ],
      );
      if (croppedFile == null) return; // user cancelled crop

      setState(() => _isUploading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isUploading = false);
        return;
      }

      final bytes = await croppedFile.readAsBytes();
      if (bytes.isEmpty) throw Exception('Selected image is empty.');

      const cloudName = 'dotlyaqsr';
      const apiKey = '594354471714585';
      const apiSecret = 'teR8IfY90hth1VpWge_9Bhoi4k4';
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final paramsToSign =
          'folder=profile_images&public_id=${user.uid}&timestamp=$timestamp$apiSecret';
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
      if (response.statusCode != 200) throw Exception('Cloudinary upload failed: $responseData');

      final jsonMap = json.decode(responseData);
      final downloadUrl = jsonMap['secure_url'];
      await user.updatePhotoURL(downloadUrl);
      await user.reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
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
                    leading: const Icon(Icons.person_search_rounded, color: Color(0xFFF0A500)),
                    title: const Text('View photo', style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF5C4033))),
                    onTap: () {
                      Navigator.pop(context);
                      _viewProfilePicture(context, photoUrl);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: Color(0xFFF0A500)),
                  title: const Text('Upload from gallery', style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF5C4033))),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadImage();
                  },
                ),
                if (photoUrl != null)
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFB71C1C)),
                    title: const Text('Remove photo',
                        style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFFB71C1C))),
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

  void _showNotificationsPanel(BuildContext context) {
    bool pushEnabled = true;
    bool bellEnabled = true;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFB71C1C),
                ),
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('Push Notifications',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF5C4033))),
                subtitle: const Text('Receive donation & event updates',
                    style: TextStyle(fontSize: 12, color: Color(0xFF5C4033))),
                value: pushEnabled,
                activeTrackColor: const Color(0xFFB71C1C),
                secondary: const Icon(Icons.notifications_outlined, color: Color(0xFFF0A500)),
                onChanged: (v) => setModal(() => pushEnabled = v),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Bell Sound',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF5C4033))),
                subtitle: const Text('Play sound when a notification arrives',
                    style: TextStyle(fontSize: 12, color: Color(0xFF5C4033))),
                value: bellEnabled,
                activeTrackColor: const Color(0xFFB71C1C),
                secondary: const Icon(Icons.volume_up_rounded, color: Color(0xFFF0A500)),
                onChanged: (v) => setModal(() => bellEnabled = v),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
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
            InteractiveViewer(child: Image.network(photoUrl, fit: BoxFit.contain)),
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
      const cloudName = 'dotlyaqsr';
      const apiKey = '594354471714585';
      const apiSecret = 'teR8IfY90hth1VpWge_9Bhoi4k4';
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final publicId = 'profile_images/${user.uid}';
      final paramsToSign = 'public_id=$publicId&timestamp=$timestamp$apiSecret';
      final signature = sha1.convert(utf8.encode(paramsToSign)).toString();

      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/destroy');
      await http.post(uri, body: {
        'public_id': publicId,
        'api_key': apiKey,
        'timestamp': timestamp.toString(),
        'signature': signature,
      });

      await user.updatePhotoURL(null);
      await user.reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to remove photo: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? _userData['name'] ?? 'User Name';
    final email = user?.email ?? _userData['email'] ?? 'username@example.com';
    final photoUrl = user?.photoURL;
    final completion = _calcCompletion();
    final isComplete = completion >= 1.0;
    final ringColor = isComplete ? const Color(0xFF24963F) : const Color(0xFFB71C1C);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),

            // ── Profile avatar with completion ring ──
            GestureDetector(
              onTap: () => _showProfileOptions(context, photoUrl),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Completion ring (SizedBox + CustomPaint)
                  SizedBox(
                    width: 152,
                    height: 152,
                    child: CustomPaint(
                      painter: _CompletionRingPainter(
                        progress: completion,
                        color: ringColor,
                        trackColor: ringColor.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  // Avatar
                  Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.07),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      image: photoUrl != null
                          ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover)
                          : null,
                    ),
                    child: photoUrl == null
                        ? const Icon(Icons.account_circle, size: 132, color: Colors.black87)
                        : null,
                  ),
                  if (_isUploading)
                    Container(
                      width: 132,
                      height: 132,
                      decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                      child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                    ),
                  // Completion badge (bottom-right)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: ringColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(
                        isComplete ? '✓ Complete' : '${(completion * 100).round()}%',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Deactivation status banner ──
            _buildDeactivationBanner(),

            // Completion hint
            if (!isComplete)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFB71C1C).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFB71C1C)),
                    const SizedBox(width: 6),
                    Text(
                      'Complete your profile to unlock all features',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            Text(name,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 6),
            Text(email, style: const TextStyle(fontSize: 15, color: Colors.grey)),
            const SizedBox(height: 36),

            // Settings label
            Align(
              alignment: Alignment.centerLeft,
              child: const Text('Settings',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFB71C1C))),
            ),
            const SizedBox(height: 12),

            // Settings Card
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
              child: Column(
                children: [
                  // Public profile toggle
                  SwitchListTile(
                    title: const Text('Public Profile (Top Donators)',
                        style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF5C4033))),
                    subtitle: const Text('Allow others to see you on the leaderboard',
                        style: TextStyle(fontSize: 12, color: Color(0xFF5C4033))),
                    value: _isPublic,
                    activeTrackColor: const Color(0xFFB71C1C),
                    secondary: const Icon(Icons.visibility_rounded, color: Color(0xFFF0A500)),
                    onChanged: _togglePrivacy,
                  ),
                  const Divider(height: 1),

                  // Notifications
                  _ProfileMenuItem(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    onTap: () => _showNotificationsPanel(context),
                  ),
                  const Divider(height: 1),

                  // Edit Profile
                  _ProfileMenuItem(
                    icon: Icons.edit_outlined,
                    title: 'Edit Profile',
                    onTap: () async {
                      await Navigator.push(
                          context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                      _loadUserData(); // Refresh completion ring
                    },
                  ),
                  const Divider(height: 1),

                  // Payment & Bank Settings
                  _ProfileMenuItem(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Payment & Bank Settings',
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const PaymentSettingsScreen())),
                  ),
                  const Divider(height: 1),

                  // Profile photo change
                  _ProfileMenuItem(
                    icon: Icons.camera_alt_outlined,
                    title: 'Change Profile Photo',
                    onTap: () => _showProfileOptions(context, photoUrl),
                  ),

                  if (FirebaseAuth.instance.currentUser?.email == 'punyadaan5@gmail.com') ...[
                    const Divider(height: 1),
                    _ProfileMenuItem(
                      icon: Icons.admin_panel_settings_rounded,
                      title: 'Admin: Add Organization',
                      onTap: () => Navigator.push(
                          context, MaterialPageRoute(builder: (_) => const AddOrganizationScreen())),
                    ),
                  ],
                  const Divider(height: 1),
                  _ProfileMenuItem(icon: Icons.contrast_rounded, title: 'Theme', onTap: () {}),
                  const Divider(height: 1),
                  _ProfileMenuItem(icon: Icons.policy_outlined, title: 'Policies', onTap: () {}),
                  const Divider(height: 1),
                  _ProfileMenuItem(
                      icon: Icons.article_outlined, title: 'Terms and Conditions', onTap: () {}),
                  const Divider(height: 1),
                  _ProfileMenuItem(icon: Icons.info_outline_rounded, title: 'About Us', onTap: () {}),
                  const Divider(height: 1),
                  _ProfileMenuItem(
                      icon: Icons.help_outline_rounded, title: 'Support / Help', onTap: () {}),
                  // Deactivate Account — shown only if not already requested
                  if (_deactivationStatus == 'none' || _deactivationStatus == 'rejected') ...[
                    const Divider(height: 1),
                    _DeactivateMenuItem(onTap: _showDeactivateDialog),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Log Out
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => _confirmSignOut(context),
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                label: const Text('Log Out',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB71C1C),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

// ── Completion Ring Painter ────────────────────────────────────────
class _CompletionRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  const _CompletionRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 5.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    const startAngle = -3.14159 / 2; // top
    const fullSweep = 2 * 3.14159;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      fullSweep * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CompletionRingPainter old) =>
      old.progress != progress || old.color != color;
}

// ── Profile Menu Item ──────────────────────────────────────────────
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
            Icon(icon, size: 22, color: Color(0xFFF0A500)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF5C4033))),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF5C4033)),
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
                color: const Color(0xFFB71C1C).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.person_off_rounded,
                  size: 18, color: Color(0xFFB71C1C)),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Deactivate Account',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFB71C1C),
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
