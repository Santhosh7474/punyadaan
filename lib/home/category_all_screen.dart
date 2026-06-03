import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:ui';
import '../models/organization_model.dart';
import 'organization_detail_screen.dart';
import 'event_detail_screen.dart';

class CategoryAllScreen extends StatefulWidget {
  final String title;
  final String category;
  final Position? currentPosition;

  const CategoryAllScreen({
    super.key,
    required this.title,
    required this.category,
    this.currentPosition,
  });

  @override
  State<CategoryAllScreen> createState() => _CategoryAllScreenState();
}

class _CategoryAllScreenState extends State<CategoryAllScreen> {
  late final Stream<QuerySnapshot> _orgStream;
  late final Stream<QuerySnapshot> _eventStream;

  @override
  void initState() {
    super.initState();
    // For the 'donator_event' category there are no organizations — only events.
    if (widget.category == 'donator_event') {
      _orgStream = const Stream.empty();
    } else {
      _orgStream = FirebaseFirestore.instance
          .collection('organizations')
          .where('status', isEqualTo: 'approved')
          .where('category', whereIn: [widget.category, widget.category.toLowerCase()])
          .snapshots();
    }
    _eventStream = FirebaseFirestore.instance
        .collection('events')
        .where('status', isEqualTo: 'approved')
        .where('category', isEqualTo: widget.category)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FD),
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _orgStream,
        builder: (context, orgSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: _eventStream,
            builder: (context, eventSnapshot) {
              if (orgSnapshot.connectionState == ConnectionState.waiting &&
                  eventSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFE89344)));
              }

              // Combined items list: orgs first, then events
              final List<Map<String, dynamic>> items = [];

              if (orgSnapshot.hasData) {
                for (var doc in orgSnapshot.data!.docs) {
                  items.add({'type': 'org', 'doc': doc});
                }
              }
              if (eventSnapshot.hasData) {
                for (var doc in eventSnapshot.data!.docs) {
                  items.add({'type': 'event', 'doc': doc});
                }
              }

              if (items.isEmpty) {
                return Center(
                  child: Text(
                    'No locations or events found for ${widget.title}.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];

                  if (item['type'] == 'org') {
                    final doc = item['doc'] as QueryDocumentSnapshot;
                    final org = Organization.fromFirestore(doc);

                    String distanceText = 'N/A';
                    if (widget.currentPosition != null && org.locationPin != null) {
                      double distanceInMeters = Geolocator.distanceBetween(
                        widget.currentPosition!.latitude,
                        widget.currentPosition!.longitude,
                        org.locationPin!.latitude,
                        org.locationPin!.longitude,
                      );
                      distanceText = '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrganizationDetailScreen(
                                organization: org,
                                currentPosition: widget.currentPosition,
                              ),
                            ),
                          );
                        },
                        child: _FullWidthOrgCard(
                          title: org.name,
                          distance: distanceText,
                          location: org.locationName,
                          imageUrl: org.imageUrl,
                          isEvent: false,
                        ),
                      ),
                    );
                  } else {
                    // Event item
                    final doc = item['doc'] as QueryDocumentSnapshot;
                    final data = doc.data() as Map<String, dynamic>;
                    final eventId = doc.id;
                    final imageUrl = data['imageUrl'] as String? ?? '';
                    final title = data['title'] ?? data['name'] ?? 'Unnamed Event';
                    final creatorName = data['creatorName'] ?? 'Unknown';
                    final targetAmount = data['targetAmount'] ?? 0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EventDetailScreen(
                                eventId: eventId,
                                eventData: data,
                              ),
                            ),
                          );
                        },
                        child: _FullWidthOrgCard(
                          title: title,
                          distance: 'By: $creatorName',
                          location: 'Target: ₹${(targetAmount as num).toStringAsFixed(0)}',
                          imageUrl: imageUrl,
                          isEvent: true,
                        ),
                      ),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _FullWidthOrgCard extends StatelessWidget {
  final String title;
  final String distance;
  final String location;
  final String imageUrl;
  final bool isEvent;

  const _FullWidthOrgCard({
    required this.title,
    required this.distance,
    required this.location,
    required this.imageUrl,
    this.isEvent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140, // Slightly taller landscape card
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(2, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            children: [
              Container(
                width: 140,
                decoration: BoxDecoration(
                  image: imageUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(imageUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: isEvent ? const Color(0xFF24963F).withValues(alpha: 0.15) : Colors.grey.shade200,
                ),
                child: imageUrl.isEmpty
                    ? Center(
                        child: Icon(
                          isEvent ? Icons.event_rounded : Icons.location_city_rounded,
                          size: 40,
                          color: isEvent ? const Color(0xFF24963F) : Colors.grey,
                        ),
                      )
                    : null,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isEvent)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF24963F).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Event',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF24963F),
                            ),
                          ),
                        ),
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            isEvent ? Icons.person_rounded : Icons.location_on,
                            size: 14,
                            color: isEvent ? const Color(0xFF24963F) : Colors.redAccent,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              distance,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        location,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isEvent ? Colors.amber.shade700 : const Color(0xFFE89344),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
