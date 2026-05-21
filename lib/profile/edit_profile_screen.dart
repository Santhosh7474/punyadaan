import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:punyadaan/services/notification_sound_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isDetectingLocation = false;
  bool _notificationsEnabled = true;
  bool _bellSoundEnabled = true;

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _aadharCtrl = TextEditingController();
  final _panCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Pre-fill email from auth
    if (user.email != null && user.email!.isNotEmpty) {
      _emailCtrl.text = user.email!;
    }

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!doc.exists) return;
    final data = doc.data()!;

    setState(() {
      _firstNameCtrl.text = data['firstName'] ?? '';
      _lastNameCtrl.text = data['lastName'] ?? '';
      if (_emailCtrl.text.isEmpty) _emailCtrl.text = data['email'] ?? '';
      _locationCtrl.text = data['location'] ?? '';
      _aadharCtrl.text = data['aadharNumber'] ?? '';
      _panCtrl.text = data['panNumber'] ?? '';
      _notificationsEnabled = data['notificationsEnabled'] ?? true;
      _bellSoundEnabled = data['bellSoundEnabled'] ?? true;
    });
  }

  Future<void> _autoDetectLocation() async {
    setState(() => _isDetectingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Location services are disabled.');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnack('Location permission denied.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnack('Location permission permanently denied.');
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [p.street, p.locality, p.administrativeArea, p.country]
            .where((s) => s != null && s.isNotEmpty)
            .toList();
        setState(() => _locationCtrl.text = parts.join(', '));
      }
    } catch (e) {
      _showSnack('Could not detect location: $e');
    } finally {
      if (mounted) setState(() => _isDetectingLocation = false);
    }
  }

  void _showSnack(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      final firstName = _firstNameCtrl.text.trim();
      final lastName = _lastNameCtrl.text.trim();
      final fullName = '$firstName $lastName'.trim();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'firstName': firstName,
        'lastName': lastName,
        'name': fullName,
        'email': _emailCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'aadharNumber': _aadharCtrl.text.trim(),
        'panNumber': _panCtrl.text.trim().toUpperCase(),
        'notificationsEnabled': _notificationsEnabled,
        'bellSoundEnabled': _bellSoundEnabled,
      }, SetOptions(merge: true));

      // Update display name in Firebase Auth
      if (fullName.isNotEmpty) await user.updateDisplayName(fullName);

      if (mounted) {
        _showSnack('Profile updated successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnack('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _locationCtrl.dispose();
    _aadharCtrl.dispose();
    _panCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save', style: TextStyle(color: Color(0xFFB71C1C), fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('Personal Information'),
              _buildCard([
                _buildField(
                  controller: _firstNameCtrl,
                  label: 'First Name',
                  icon: Icons.person_outline_rounded,
                  hint: 'Enter first name',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                _divider(),
                _buildField(
                  controller: _lastNameCtrl,
                  label: 'Last Name',
                  icon: Icons.person_outline_rounded,
                  hint: 'Enter last name',
                ),
                _divider(),
                _buildField(
                  controller: _emailCtrl,
                  label: 'E-mail',
                  icon: Icons.email_outlined,
                  hint: 'Enter email address',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final emailReg = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                    if (!emailReg.hasMatch(v.trim())) return 'Enter a valid email';
                    return null;
                  },
                ),
              ]),

              _sectionLabel('Location'),
              _buildCard([
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on_outlined, color: Colors.black54, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _locationCtrl,
                          decoration: InputDecoration(
                            labelText: 'Location / Address',
                            labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            border: InputBorder.none,
                            hintText: 'Enter your address',
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                          ),
                          style: const TextStyle(fontSize: 15, color: Colors.black87),
                          maxLines: 2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _isDetectingLocation ? null : _autoDetectLocation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB71C1C).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: _isDetectingLocation
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFB71C1C)))
                              : const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.my_location_rounded, size: 14, color: Color(0xFFB71C1C)),
                                    SizedBox(width: 4),
                                    Text('Detect', style: TextStyle(fontSize: 11, color: Color(0xFFB71C1C), fontWeight: FontWeight.w700)),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),

              _sectionLabel('Identity Documents'),
              _buildCard([
                _buildField(
                  controller: _aadharCtrl,
                  label: 'Aadhar Number',
                  icon: Icons.credit_card_outlined,
                  hint: 'XXXX XXXX XXXX',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(12),
                    _AadharFormatter(),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final clean = v.replaceAll(' ', '');
                    if (clean.length != 12) return 'Aadhar must be 12 digits';
                    return null;
                  },
                ),
                _divider(),
                _buildField(
                  controller: _panCtrl,
                  label: 'PAN Number',
                  icon: Icons.badge_outlined,
                  hint: 'ABCDE1234F',
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(10),
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final panReg = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
                    if (!panReg.hasMatch(v.trim().toUpperCase())) return 'Invalid PAN format (e.g. ABCDE1234F)';
                    return null;
                  },
                ),
              ]),

              _sectionLabel('Preferences'),
              _buildCard([
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_outlined, color: Colors.black87, size: 22),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Notifications', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
                            SizedBox(height: 2),
                            Text('Receive alerts & updates', style: TextStyle(fontSize: 12, color: Colors.black45)),
                          ],
                        ),
                      ),
                      Switch(
                        value: _notificationsEnabled,
                        activeThumbColor: const Color(0xFFB71C1C),
                        onChanged: (val) async {
                          setState(() => _notificationsEnabled = val);
                          if (val) {
                            // Play a preview so the user hears the bell
                            await NotificationSoundService.playDirect();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 48),
                // Bell Sound toggle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.volume_up_rounded, color: Colors.black87, size: 22),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Bell Sound', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
                            SizedBox(height: 2),
                            Text('Play sound when notification arrives', style: TextStyle(fontSize: 12, color: Colors.black45)),
                          ],
                        ),
                      ),
                      Switch(
                        value: _bellSoundEnabled,
                        activeThumbColor: const Color(0xFFB71C1C),
                        onChanged: (val) async {
                          setState(() => _bellSoundEnabled = val);
                          if (val) await NotificationSoundService.playDirect();
                        },
                      ),
                    ],
                  ),
                ),
              ]),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB71C1C),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8, left: 4),
      child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600, letterSpacing: 0.5)),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(children: children),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 48);

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.words,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.black54, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              textCapitalization: textCapitalization,
              inputFormatters: inputFormatters,
              validator: validator,
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                border: InputBorder.none,
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              ),
              style: const TextStyle(fontSize: 15, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

class _AadharFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final result = buffer.toString();
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}
