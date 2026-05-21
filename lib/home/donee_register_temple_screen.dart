import 'dart:ui';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';

class DoneeRegisterTempleScreen extends StatefulWidget {
  const DoneeRegisterTempleScreen({super.key});

  @override
  State<DoneeRegisterTempleScreen> createState() =>
      _DoneeRegisterTempleScreenState();
}

class _DoneeRegisterTempleScreenState
    extends State<DoneeRegisterTempleScreen> {
  // ── Category ─────────────────────────────────────────────────────
  String? _selectedCategory;

  static const List<String> _categories = [
    'Religious Place',
    'Gaushala',
    'Charity Organisation',
    'Yogdaan',
  ];

  /// Maps UI category label → Firestore category value
  static const Map<String, String> _categoryToFirestore = {
    'Religious Place': 'Temple',
    'Gaushala': 'Gaushala',
    'Charity Organisation': 'Charity',
    'Yogdaan': 'Yogdaan',
  };

  // ── Form controllers ────────────────────────────────────────────
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  File? _selectedImage;
  bool _detectingLocation = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────

  String get _categoryLabel => _selectedCategory ?? 'Donee';

  String get _firestoreCategory =>
      _categoryToFirestore[_selectedCategory] ?? 'Temple';

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() => _selectedImage = File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _autoDetectLocation() async {
    setState(() => _detectingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services disabled');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }

      final pos = await Geolocator.getCurrentPosition();
      final placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
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

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty ||
        _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill all fields and select an image.')),
      );
      return;
    }

    const primaryGreen = Color(0xFF24963F);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: primaryGreen)),
    );

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in.');

      // Upload image to Cloudinary
      final bytes = await _selectedImage!.readAsBytes();
      const cloudName = 'dotlyaqsr';
      const apiKey = '594354471714585';
      const apiSecret = 'teR8IfY90hth1VpWge_9Bhoi4k4';

      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final paramsToSign = 'folder=temples&timestamp=$timestamp$apiSecret';
      final signature = sha1.convert(utf8.encode(paramsToSign)).toString();

      final uri =
          Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['api_key'] = apiKey
        ..fields['timestamp'] = timestamp.toString()
        ..fields['signature'] = signature
        ..fields['folder'] = 'temples'
        ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: 'temple.jpg'));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        throw Exception('Cloudinary Error: $responseData');
      }

      final imageUrl = json.decode(responseData)['secure_url'];

      await FirebaseFirestore.instance.collection('organizations').add({
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'locationName': _locationController.text.trim(),
        'category': _firestoreCategory,
        'imageUrl': imageUrl,
        'status': 'waiting',
        'doneeId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      navigator.pop(); // hide loader
      scaffoldMessenger.showSnackBar(
        SnackBar(
            content: Text(
                '$_categoryLabel registration submitted! Pending admin approval.')),
      );

      if (mounted) {
        _nameController.clear();
        _descController.clear();
        _locationController.clear();
        setState(() {
          _selectedImage = null;
          _selectedCategory = null;
        });
      }
    } catch (e) {
      navigator.pop(); // hide loader
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Failed to register: $e')),
      );
    }
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF24963F);

    return SingleChildScrollView(
      padding:
          const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 120),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title ────────────────────────────────────────────
            Text(
              _selectedCategory == null
                  ? 'Register Donee'
                  : 'Register $_categoryLabel',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: primaryGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Submit your donee details for verification',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 24),

            // ── Category Dropdown ─────────────────────────────────
            _buildGlassyDropdown(primaryGreen),

            // ── Form (hidden until category selected) ────────────
            if (_selectedCategory != null) ...[
              const SizedBox(height: 24),

              // Image upload
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: _selectedImage != null
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(_selectedImage!,
                                      fit: BoxFit.cover),
                                  Container(
                                    color: Colors.black12,
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.edit_rounded,
                                        color: Colors.white, size: 36),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_rounded,
                                      size: 48,
                                      color: primaryGreen.withValues(alpha: 0.7)),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Tap to upload $_categoryLabel image',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Name
              _buildGlassyTextField(
                controller: _nameController,
                label: '$_categoryLabel Name',
                icon: _categoryIcon(),
                hint: 'e.g. Sri Venkateswara $_categoryLabel',
                accentColor: primaryGreen,
              ),

              const SizedBox(height: 16),

              // Location with auto-detect
              _buildLocationField(primaryGreen),

              const SizedBox(height: 16),

              // Description
              _buildGlassyTextField(
                controller: _descController,
                label: 'Description & History',
                icon: Icons.description_rounded,
                hint: 'Describe the $_categoryLabel...',
                maxLines: 4,
                accentColor: primaryGreen,
              ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 8,
                    shadowColor: primaryGreen.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Register $_categoryLabel',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon() {
    switch (_selectedCategory) {
      case 'Gaushala':
        return Icons.pets_rounded;
      case 'Charity Organisation':
        return Icons.volunteer_activism_rounded;
      case 'Yogdaan':
        return Icons.self_improvement_rounded;
      default:
        return Icons.temple_hindu_rounded;
    }
  }

  Widget _buildGlassyDropdown(Color accentColor) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                border: InputBorder.none,
                labelText: 'Select Category',
                icon: Icon(Icons.category_rounded, color: accentColor),
                labelStyle: TextStyle(color: Colors.grey.shade700),
              ),
              hint: Text('Choose a category',
                  style: TextStyle(color: Colors.grey.shade500)),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedCategory = val;
                  // reset form when category changes
                  _nameController.clear();
                  _descController.clear();
                  _locationController.clear();
                  _selectedImage = null;
                });
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationField(Color accentColor) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _locationController,
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      labelText: 'Location Details',
                      hintText: 'e.g. Jubilee Hills, Hyderabad',
                      icon: Icon(Icons.location_on_rounded, color: accentColor),
                      labelStyle: TextStyle(color: Colors.grey.shade700),
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _autoDetectLocation,
                  child: _detectingLocation
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Tooltip(
                          message: 'Auto-detect location',
                          child: Icon(Icons.my_location_rounded,
                              color: accentColor, size: 22),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassyTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color accentColor,
    String? hint,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
              decoration: InputDecoration(
                border: InputBorder.none,
                labelText: label,
                hintText: hint,
                icon: Icon(icon, color: accentColor),
                labelStyle: TextStyle(color: Colors.grey.shade700),
                hintStyle: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
