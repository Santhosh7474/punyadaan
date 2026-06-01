// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:punyadaan/services/notification_sound_service.dart';

class DoneeEditProfileScreen extends StatefulWidget {
  const DoneeEditProfileScreen({super.key});

  @override
  State<DoneeEditProfileScreen> createState() => _DoneeEditProfileScreenState();
}

class _DoneeEditProfileScreenState extends State<DoneeEditProfileScreen> {
  static const _primaryRed = Color(0xFFB71C1C);
  static const _primaryGreen = Color(0xFF24963F);

  // ── Bank Account ─────────────────────────────────────────────────
  final _bankNameController = TextEditingController();
  final _accountNoController = TextEditingController();
  final _ifscController = TextEditingController();

  // ── Section 80G ──────────────────────────────────────────────────
  final _sec80gRegController = TextEditingController();
  final _sec80gValidityController = TextEditingController();

  // ── Auth extras ──────────────────────────────────────────────────
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  // ── Location ─────────────────────────────────────────────────────
  final _locationController = TextEditingController();
  bool _detectingLocation = false;

  // ── Notifications ───────────────────────────────────────────────────
  bool _notificationsEnabled = true;
  bool _bellSoundEnabled = true;

  // ── Document upload ──────────────────────────────────────────────
  File? _registrationDoc;
  String? _docUrl;
  bool _uploadingDoc = false;

  // ── General ──────────────────────────────────────────────────────
  bool _loading = true;
  bool _saving = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNoController.dispose();
    _ifscController.dispose();
    _sec80gRegController.dispose();
    _sec80gValidityController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('donee_profiles')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final d = doc.data()!;
        final bank = d['bank'] as Map<String, dynamic>? ?? {};
        final sec80g = d['section80G'] as Map<String, dynamic>? ?? {};

        _bankNameController.text = bank['bankName'] ?? '';
        _accountNoController.text = bank['accountNumber'] ?? '';
        _ifscController.text = bank['ifscCode'] ?? '';
        _sec80gRegController.text = sec80g['registrationNumber'] ?? '';
        _sec80gValidityController.text = sec80g['validityDate'] ?? '';
        _locationController.text = d['location'] ?? '';
        _docUrl = d['registrationDocUrl'] as String?;
        _notificationsEnabled = d['notificationsEnabled'] ?? true;
        _bellSoundEnabled = d['bellSoundEnabled'] ?? true;
      }
    } catch (_) {}

    setState(() => _loading = false);
  }

  // ── Location auto-detect ─────────────────────────────────────────
  Future<void> _autoDetectLocation() async {
    setState(() => _detectingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services disabled');

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }

      final pos = await Geolocator.getCurrentPosition();
      final marks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (marks.isNotEmpty) {
        final p = marks.first;
        final parts = [p.subLocality, p.locality, p.administrativeArea]
            .where((s) => s != null && s.isNotEmpty)
            .join(', ');
        setState(() => _locationController.text = parts);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not detect location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _detectingLocation = false);
    }
  }

  // ── Document upload ──────────────────────────────────────────────
  Future<void> _pickAndUploadDocument() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file == null) return;

      setState(() {
        _registrationDoc = File(file.path);
        _uploadingDoc = true;
      });

      final user = FirebaseAuth.instance.currentUser!;
      final bytes = await _registrationDoc!.readAsBytes();

      const cloudName = 'dotlyaqsr';
      const apiKey = '594354471714585';
      const apiSecret = 'teR8IfY90hth1VpWge_9Bhoi4k4';

      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final paramsToSign =
          'folder=donee_docs&public_id=${user.uid}_regcert&timestamp=$timestamp$apiSecret';
      final signature = sha1.convert(utf8.encode(paramsToSign)).toString();

      final uri =
          Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['api_key'] = apiKey
        ..fields['timestamp'] = timestamp.toString()
        ..fields['signature'] = signature
        ..fields['folder'] = 'donee_docs'
        ..fields['public_id'] = '${user.uid}_regcert'
        ..files.add(http.MultipartFile.fromBytes('file', bytes,
            filename: 'regcert.jpg'));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final url = json.decode(responseData)['secure_url'] as String;
        setState(() => _docUrl = url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document uploaded successfully')),
          );
        }
      } else {
        throw Exception('Upload failed: $responseData');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingDoc = false);
    }
  }

  // ── Save ─────────────────────────────────────────────────────────
  Future<void> _saveAll() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('donee_profiles')
          .doc(user.uid)
          .set({
        'bank': {
          'bankName': _bankNameController.text.trim(),
          'accountNumber': _accountNoController.text.trim(),
          'ifscCode': _ifscController.text.trim().toUpperCase(),
        },
        'section80G': {
          'registrationNumber': _sec80gRegController.text.trim(),
          'validityDate': _sec80gValidityController.text.trim(),
        },
        'location': _locationController.text.trim(),
        'registrationDocUrl': _docUrl ?? '',
        'notificationsEnabled': _notificationsEnabled,
        'bellSoundEnabled': _bellSoundEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved successfully'),
            backgroundColor: Color(0xFFB71C1C),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isPhoneLogin =
        user?.providerData.any((p) => p.providerId == 'phone') ?? false;
    final hasEmail = user?.email != null && user!.email!.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FD),
      appBar: AppBar(
        title: const Text('Edit Profile',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: Color(0xFFB71C1C))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFFB71C1C),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primaryGreen))
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF6F8FD), Color(0xFFE9F0E6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Bank Account Details ──────────────────────
                    _sectionHeader(
                        'Bank Account Details', Icons.account_balance_rounded),
                    const SizedBox(height: 12),
                    _glassCard(children: [
                      _formField(
                        controller: _bankNameController,
                        label: 'Bank Name',
                        icon: Icons.account_balance_outlined,
                        hint: 'e.g. State Bank of India',
                      ),
                      _divider(),
                      _formField(
                        controller: _accountNoController,
                        label: 'Account Number',
                        icon: Icons.numbers_rounded,
                        hint: 'Enter account number',
                        inputType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        obscureText: true,
                      ),
                      _divider(),
                      _formField(
                        controller: _ifscController,
                        label: 'IFSC Code',
                        icon: Icons.code_rounded,
                        hint: 'e.g. SBIN0001234',
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ]),

                    const SizedBox(height: 28),

                    // ── Registration Document ─────────────────────
                    _sectionHeader('Registration Certificate',
                        Icons.upload_file_rounded),
                    const SizedBox(height: 12),
                    _docUploadCard(),

                    const SizedBox(height: 28),

                    // ── Section 80G ───────────────────────────────
                    _sectionHeader(
                        'Section 80G Details', Icons.article_rounded),
                    const SizedBox(height: 12),
                    _glassCard(children: [
                      _formField(
                        controller: _sec80gRegController,
                        label: '80G Registration Number',
                        icon: Icons.verified_outlined,
                        hint: 'e.g. 80G/2024/ABCD1234',
                      ),
                      _divider(),
                      _formField(
                        controller: _sec80gValidityController,
                        label: 'Validity Date',
                        icon: Icons.calendar_today_rounded,
                        hint: 'DD/MM/YYYY',
                        inputType: TextInputType.datetime,
                      ),
                    ]),

                    const SizedBox(height: 28),

                    // ── Auth extras ───────────────────────────────
                    if (isPhoneLogin && !hasEmail) ...[
                      _sectionHeader('Add Email Address', Icons.email_rounded),
                      const SizedBox(height: 12),
                      _glassCard(children: [
                        _formField(
                          controller: _emailController,
                          label: 'Email Address',
                          icon: Icons.mail_outline_rounded,
                          hint: 'e.g. name@example.com',
                          inputType: TextInputType.emailAddress,
                        ),
                      ]),
                      const SizedBox(height: 28),
                    ],

                    if (!isPhoneLogin) ...[
                      _sectionHeader('Add Phone Number', Icons.phone_rounded),
                      const SizedBox(height: 12),
                      _glassCard(children: [
                        _formField(
                          controller: _phoneController,
                          label: 'Phone Number',
                          icon: Icons.phone_outlined,
                          hint: '+91 9XXXXXXXXX',
                          inputType: TextInputType.phone,
                        ),
                      ]),
                      const SizedBox(height: 28),
                    ],

                    // ── Location ──────────────────────────────────
                    _sectionHeader(
                        'Location', Icons.location_on_rounded),
                    const SizedBox(height: 12),
                    _locationCard(),

                    const SizedBox(height: 28),

                    // ── Notifications ─────────────────────────────
                    _sectionHeader(
                        'Notifications', Icons.notifications_rounded),
                    const SizedBox(height: 12),
                    _notificationCard(),
                    const SizedBox(height: 10),
                    _bellSoundCard(),

                    const SizedBox(height: 36),

                    // ── Save Button ───────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveAll,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryRed,
                          foregroundColor: Colors.white,
                          elevation: 6,
                          shadowColor: _primaryRed.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5))
                            : const Text('Save Changes',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Reusable section header ───────────────────────────────────────
  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0A500),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Icon(icon, size: 20, color: const Color(0xFF5C4033)),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFFB71C1C))),
      ],
    );
  }

  // ── Glassy card wrapper ───────────────────────────────────────────
  Widget _glassCard({required List<Widget> children}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.9), width: 1.2),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(children: children),
        ),
      ),
    );
  }

  Widget _divider() =>
      const Divider(height: 1, indent: 52, endIndent: 16, thickness: 0.5);

  // ── Form field ────────────────────────────────────────────────────
  Widget _formField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType inputType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    bool obscureText = false,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: TextField(
        controller: controller,
        keyboardType: inputType,
        inputFormatters: inputFormatters,
        obscureText: obscureText,
        textCapitalization: textCapitalization,
        style: const TextStyle(fontSize: 15, color: Color(0xFF5C4033)),
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          hintText: hint,
          icon: Icon(icon, color: const Color(0xFFF0A500), size: 20),
          labelStyle:
              const TextStyle(color: Color(0xFF5C4033), fontSize: 13),
          hintStyle:
              TextStyle(color: Colors.grey.shade400, fontSize: 13),
        ),
      ),
    );
  }

  // ── Document upload card ──────────────────────────────────────────
  Widget _docUploadCard() {
    return GestureDetector(
      onTap: _uploadingDoc ? null : _pickAndUploadDocument,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.9), width: 1.2),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: _uploadingDoc
                ? const Center(
                    child: CircularProgressIndicator(color: _primaryRed))
                : _docUrl != null || _registrationDoc != null
                    ? Row(children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: _primaryGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.check_circle_rounded,
                              color: _primaryGreen, size: 28),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Document Uploaded',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: _primaryGreen)),
                              SizedBox(height: 2),
                              Text('Tap to replace',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ])
                    : Row(children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: _primaryRed.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.upload_file_rounded,
                              color: _primaryRed, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Upload Registration Certificate',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87)),
                              const SizedBox(height: 2),
                              Text('Tap to select from gallery',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                      ]),
          ),
        ),
      ),
    );
  }

  // ── Location card ─────────────────────────────────────────────────
  Widget _locationCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.9), width: 1.2),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _locationController,
                  style:
                      const TextStyle(fontSize: 15, color: Colors.black87),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    labelText: 'Your Location',
                    hintText: 'e.g. Hyderabad, Telangana',
                    icon: const Icon(Icons.location_on_outlined,
                        color: Color(0xFFF0A500), size: 20),
                    labelStyle: const TextStyle(
                        color: Color(0xFF5C4033), fontSize: 13),
                    hintStyle: TextStyle(
                        color: Colors.grey.shade400, fontSize: 13),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _autoDetectLocation,
                child: _detectingLocation
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFFF0A500)),
                      )
                    : Tooltip(
                        message: 'Auto-detect location',
                        child: const Icon(Icons.my_location_rounded,
                            color: Color(0xFFF0A500), size: 22),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Notification card ─────────────────────────────────────────────
  Widget _notificationCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.9), width: 1.2),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _notificationsEnabled
                      ? _primaryRed.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _notificationsEnabled
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_outlined,
                  color:
                      _notificationsEnabled ? const Color(0xFFF0A500) : Colors.grey,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Push Notifications',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: Color(0xFF5C4033))),
                    Text(
                      _notificationsEnabled ? 'Bell sounds on' : 'Muted',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _notificationsEnabled,
                activeTrackColor: _primaryRed,
                onChanged: (val) async {
                  setState(() => _notificationsEnabled = val);
                  if (val) {
                    // Play a preview so the user hears the bell immediately
                    await NotificationSoundService.playDirect();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bell Sound card ──────────────────────────────────────────────
  Widget _bellSoundCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.9), width: 1.2),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _bellSoundEnabled
                      ? _primaryRed.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _bellSoundEnabled
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  color: _bellSoundEnabled ? const Color(0xFFF0A500) : Colors.grey,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Bell Sound',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: Color(0xFF5C4033))),
                    Text(
                      _bellSoundEnabled ? 'Plays on notification' : 'Silent',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _bellSoundEnabled,
                activeTrackColor: _primaryRed,
                onChanged: (val) async {
                  setState(() => _bellSoundEnabled = val);
                  if (val) await NotificationSoundService.playDirect();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
