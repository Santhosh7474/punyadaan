import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  final String id;
  final String name;
  final String date;
  final String imageUrl;
  final String status;
  final String creatorUid;
  final String creatorName;

  Event({
    required this.id,
    required this.name,
    required this.date,
    required this.imageUrl,
    required this.status,
    required this.creatorUid,
    required this.creatorName,
  });

  factory Event.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Event(
      id: doc.id,
      name: data['name'] ?? 'Unknown Event',
      date: data['date'] ?? 'No Date Specified',
      imageUrl: data['imageUrl'] ?? '',
      status: data['status'] ?? 'pending',
      creatorUid: data['creatorUid'] ?? '',
      creatorName: data['creatorName'] ?? 'Unknown Creator',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'date': date,
      'imageUrl': imageUrl,
      'status': status,
      'creatorUid': creatorUid,
      'creatorName': creatorName,
    };
  }
}
