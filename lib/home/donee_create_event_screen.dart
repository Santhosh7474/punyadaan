import 'dart:ui';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';


class DoneeCreateEventScreen extends StatefulWidget {
  const DoneeCreateEventScreen({super.key});

  @override
  State<DoneeCreateEventScreen> createState() => _DoneeCreateEventScreenState();
}

class _DoneeCreateEventScreenState extends State<DoneeCreateEventScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  String _selectedCategory = 'Temple';
  File? _selectedImage;

  final ImagePicker _picker = ImagePicker();
  final List<String> _categories = [
    'Temple',
    'Gaushala',
    'Charity',
    'Kanyadaan',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _amountController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF24963F);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 120),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Create Request',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: primaryGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Submit a request for funds or assistance',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 24),

            // Image Upload Section (Glassmorphic)
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
                                Image.file(_selectedImage!, fit: BoxFit.cover),
                                Container(
                                  color: Colors.black12,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.edit_rounded,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_rounded,
                                  size: 48,
                                  color: primaryGreen.withValues(alpha: 0.7),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Tap to upload event image',
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

            _buildGlassyTextField(
              controller: _titleController,
              label: 'Request Title',
              icon: Icons.title_rounded,
              hint: 'e.g. Temple Renovation',
              accentColor: primaryGreen,
            ),
            const SizedBox(height: 16),

            _buildGlassyTextField(
              controller: _locationController,
              label: 'Location',
              icon: Icons.location_on_rounded,
              hint: 'e.g. Jubilee Hills, Hyderabad',
              accentColor: primaryGreen,
            ),
            const SizedBox(height: 16),

            // Dropdown Category
            _buildGlassyDropdown(accentColor: primaryGreen),

            const SizedBox(height: 16),
            _buildGlassyTextField(
              controller: _amountController,
              label: 'Target Amount (₹)',
              icon: Icons.currency_rupee_rounded,
              hint: 'e.g. 50000',
              keyboardType: TextInputType.number,
              accentColor: primaryGreen,
            ),

            const SizedBox(height: 16),
            _buildGlassyTextField(
              controller: _descController,
              label: 'Description',
              icon: Icons.description_rounded,
              hint: 'Describe why you need these funds...',
              maxLines: 4,
              accentColor: primaryGreen,
            ),

            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () async {
                  if (_titleController.text.trim().isEmpty ||
                      _amountController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill all required fields.'),
                      ),
                    );
                    return;
                  }

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const Center(
                      child: CircularProgressIndicator(color: primaryGreen),
                    ),
                  );

                  try {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) throw Exception("User not logged in.");

                    String? imageUrl;

                    if (_selectedImage != null) {
                      final bytes = await _selectedImage!.readAsBytes();
                      final cloudName = 'dotlyaqsr';
                      final apiKey = '594354471714585';
                      final apiSecret = 'teR8IfY90hth1VpWge_9Bhoi4k4';

                      final timestamp =
                          DateTime.now().millisecondsSinceEpoch ~/ 1000;
                      final paramsToSign =
                          'folder=event_images&timestamp=$timestamp$apiSecret';
                      final signature = sha1
                          .convert(utf8.encode(paramsToSign))
                          .toString();

                      final uri = Uri.parse(
                        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
                      );
                      final request = http.MultipartRequest('POST', uri)
                        ..fields['api_key'] = apiKey
                        ..fields['timestamp'] = timestamp.toString()
                        ..fields['signature'] = signature
                        ..fields['folder'] = 'event_images'
                        ..files.add(
                          http.MultipartFile.fromBytes(
                            'file',
                            bytes,
                            filename: 'event.jpg',
                          ),
                        );

                      final response = await request.send();
                      final responseData = await response.stream
                          .bytesToString();

                      if (response.statusCode == 200) {
                        final jsonMap = json.decode(responseData);
                        imageUrl = jsonMap['secure_url'];
                      } else {
                        debugPrint('Cloudinary Error: $responseData');
                      }
                    }

                    await FirebaseFirestore.instance.collection('events').add({
                      'title': _titleController.text.trim(),
                      'name': _titleController.text
                          .trim(), // Keep 'name' compatible for Admin Dashboard
                      'description': _descController.text.trim(),
                      'location': _locationController.text.trim(),
                      'targetAmount':
                          double.tryParse(_amountController.text) ?? 0,
                      'receivedAmount': 0,
                      'status':
                          'pending', // Set exact required status string map
                      'category': _selectedCategory,
                      'doneeId': user.uid,
                      'creatorName': user.displayName ?? 'Donee',
                      'imageUrl': imageUrl,
                      'createdAt': FieldValue.serverTimestamp(),
                      'date':
                          '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    });

                    if (context.mounted) {
                      Navigator.pop(context); // Hide loader
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Request submitted successfully!'),
                        ),
                      );

                      _titleController.clear();
                      _descController.clear();
                      _amountController.clear();
                      _locationController.clear();
                      setState(() {
                        _selectedCategory = 'Temple';
                        _selectedImage = null;
                      });
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context); // Hide loader
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to submit request: $e')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  elevation: 8,
                  shadowColor: primaryGreen.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Submit Request',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
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
    TextInputType? keyboardType,
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
              keyboardType: keyboardType,
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

  Widget _buildGlassyDropdown({required Color accentColor}) {
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.category_rounded, color: accentColor),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategory,
                      isExpanded: true,
                      dropdownColor: Colors.white.withValues(alpha: 0.95),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.black54,
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                      items: _categories.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedCategory = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
