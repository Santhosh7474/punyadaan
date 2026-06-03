import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import '../models/organization_model.dart';

class AddOrganizationScreen extends StatefulWidget {
  final Organization? existingOrg;
  
  const AddOrganizationScreen({super.key, this.existingOrg});

  @override
  State<AddOrganizationScreen> createState() => _AddOrganizationScreenState();
}

class _AddOrganizationScreenState extends State<AddOrganizationScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _selectedCategory = 'temple';
  final List<String> _categories = ['temple', 'gaushala', 'charity', 'kanyadaan'];
  
  XFile? _selectedImage;
  String? _existingImageUrl;
  final ImagePicker _picker = ImagePicker();
  
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingOrg != null) {
      _nameController.text = widget.existingOrg!.name;
      _locationController.text = widget.existingOrg!.locationName;
      _descriptionController.text = widget.existingOrg!.description;
      _selectedCategory = widget.existingOrg!.category;
      _existingImageUrl = widget.existingOrg!.imageUrl.isNotEmpty ? widget.existingOrg!.imageUrl : null;
    }
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      maxHeight: 1000,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() => _selectedImage = image);
    }
  }

  Future<String> _uploadToCloudinary(XFile imageFile) async {
    final bytes = await imageFile.readAsBytes();
    
    final cloudName = 'dotlyaqsr';
    final apiKey = '594354471714585';
    final apiSecret = 'teR8IfY90hth1VpWge_9Bhoi4k4';
    
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    // Generate a secure random public ID just for the unique image explicitly
    final uniqueId = DateTime.now().millisecondsSinceEpoch.toString();
    final paramsToSign = 'folder=organizations&public_id=$uniqueId&timestamp=$timestamp$apiSecret';
    final signature = sha1.convert(utf8.encode(paramsToSign)).toString();

    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['api_key'] = apiKey
      ..fields['timestamp'] = timestamp.toString()
      ..fields['signature'] = signature
      ..fields['folder'] = 'organizations'
      ..fields['public_id'] = uniqueId
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: '$uniqueId.jpg'));

    final response = await request.send();
    final responseData = await response.stream.bytesToString();
    
    if (response.statusCode != 200) {
      throw Exception('Cloudinary upload failed: $responseData');
    }
    
    final jsonMap = json.decode(responseData);
    return jsonMap['secure_url'];
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (widget.existingOrg == null && _selectedImage == null && _existingImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image first.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 1. Geocode the location string — best-effort, reuse existing pin if it fails
      final locationText = _locationController.text.trim();
      GeoPoint? geoPoint;
      try {
        List<Location> locations = await locationFromAddress(locationText);
        if (locations.isNotEmpty) {
          geoPoint = GeoPoint(locations.first.latitude, locations.first.longitude);
        }
      } catch (_) {
        // Geocoding failed (e.g. ambiguous address). Keep the existing pin.
      }

      // 2. Resolve image explicitly
      String imageUrl = _existingImageUrl ?? '';
      if (_selectedImage != null) {
        imageUrl = await _uploadToCloudinary(_selectedImage!);
      }

      // 3. Prepare payload mapped identically to models securely
      final Map<String, dynamic> payload = {
        'name': _nameController.text.trim(),
        'category': _selectedCategory,
        'locationName': locationText,
        'imageUrl': imageUrl,
        'description': _descriptionController.text.trim(),
        'status': 'approved',
      };
      // Only write locationPin if we resolved a valid one
      if (geoPoint != null) {
        payload['locationPin'] = geoPoint;
      }

      if (widget.existingOrg != null) {
        // Edit mode! Update document without altering created trace manually
        await FirebaseFirestore.instance.collection('organizations').doc(widget.existingOrg!.id).update(payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Organization updated seamlessly!'), backgroundColor: Colors.blue),
          );
        }
      } else {
        // Add mode natively!
        payload['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('organizations').add(payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Organization added successfully!'), backgroundColor: Colors.green),
          );
        }
      }

      if (mounted) Navigator.of(context).pop();
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: Text(widget.existingOrg != null ? 'Edit Organization' : 'Add Organization', style: const TextStyle(color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Organization Name',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _categories.map((c) {
                  return DropdownMenuItem(
                    value: c,
                    child: Text(c.toUpperCase()),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location (e.g., Delhi, Angat)',
                  hintText: 'Type city or physical address securely',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Provide rich historical context or details...',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade400, width: 2),
                  ),
                  child: _selectedImage == null && _existingImageUrl == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_rounded, size: 48, color: Colors.grey.shade600),
                            const SizedBox(height: 8),
                            Text('Tap to select an image from your device gallery', style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _selectedImage != null
                              ? (kIsWeb 
                                  ? Image.network(_selectedImage!.path, fit: BoxFit.cover)
                                  : Image.file(File(_selectedImage!.path), fit: BoxFit.cover))
                              : Image.network(_existingImageUrl!, fit: BoxFit.cover),
                        ),
                ),
              ),
              const SizedBox(height: 32),
              
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          widget.existingOrg != null ? 'Update Organization' : 'Upload to Database',
                          style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
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
