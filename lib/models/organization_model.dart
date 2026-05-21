import 'package:cloud_firestore/cloud_firestore.dart';

class Organization {
  final String id;
  final String name;
  final String category;
  final String locationName;
  final String imageUrl;
  final String description; // Native details payload dynamically tied to detailed views
  final GeoPoint? locationPin; // Contains precise latitude & longitude
  final String? doneeId;
  final String? status; // 'waiting', 'approved', 'rejected'

  Organization({
    required this.id,
    required this.name,
    required this.category,
    required this.locationName,
    required this.imageUrl,
    required this.description,
    this.locationPin,
    this.doneeId,
    this.status,
  });

  factory Organization.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Organization(
      id: doc.id,
      name: data['name'] ?? 'Unknown',
      category: data['category'] ?? 'other',
      locationName: data['locationName'] ?? 'Unknown Location',
      imageUrl: data['imageUrl'] ?? '',
      description: data['description'] ?? 'No additional description provided at this time.',
      locationPin: data['locationPin'] as GeoPoint?,
      doneeId: data['doneeId'],
      status: data['status'] ?? 'approved', // Default to approved for older records
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'category': category,
      'locationName': locationName,
      'imageUrl': imageUrl,
      'description': description,
      if (locationPin != null) 'locationPin': locationPin,
      if (doneeId != null) 'doneeId': doneeId,
      if (status != null) 'status': status,
    };
  }
}
