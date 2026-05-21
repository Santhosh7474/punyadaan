// ignore_for_file: deprecated_member_use
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'donee_event_detail_screen.dart';

class DoneeYourEventsScreen extends StatefulWidget {
  const DoneeYourEventsScreen({super.key});

  @override
  State<DoneeYourEventsScreen> createState() => _DoneeYourEventsScreenState();
}

class _DoneeYourEventsScreenState extends State<DoneeYourEventsScreen> {
  String _selectedFilter = 'All'; // 'All', 'Approved', 'Waiting', 'Completed'

  // Map UI label → Firestore status value
  static const _filterToStatus = {
    'Waiting': 'pending',
    'Approved': 'approved',
    'Completed': 'completed',
  };

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? 'Donee';
    final photoUrl = user?.photoURL;
    const primaryGreen = Color(0xFF24963F);

    // Filtered Stream
    Query<Map<String, dynamic>> eventsQuery = FirebaseFirestore.instance
        .collection('events')
        .where('doneeId', isEqualTo: user?.uid ?? '');

    if (_selectedFilter != 'All') {
      final fsStatus =
          _filterToStatus[_selectedFilter] ?? _selectedFilter.toLowerCase();
      eventsQuery = eventsQuery.where('status', isEqualTo: fsStatus);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Your Events',
          style: TextStyle(
            color: Color(0xFF24963F),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF24963F)),
      ),
      body: Container(
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF6F8FD), Color(0xFFE9F0E6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
            bottom: 120,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Welcome Profile Card (Premium glassy feel)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: primaryGreen.withValues(alpha: 0.2),
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
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFB71C1C).withValues(alpha: 0.90),
                            const Color(0xFF7B0000).withValues(alpha: 0.90),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.3,
                            ),
                            backgroundImage: photoUrl != null
                                ? NetworkImage(photoUrl)
                                : null,
                            child: photoUrl == null
                                ? const Icon(
                                    Icons.account_circle,
                                    size: 64,
                                    color: Colors.white70,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: const TextSpan(
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    children: [
                                      TextSpan(text: 'Welcome to '),
                                      TextSpan(
                                        text: 'PunyaDaan',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextSpan(text: '!'),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                // Sum calculation via a robust sub-query stream or display static fallback
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('events')
                                      .where(
                                        'doneeId',
                                        isEqualTo: user?.uid ?? '',
                                      )
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    double totalReceived = 0;
                                    if (snapshot.hasData) {
                                      for (var doc in snapshot.data!.docs) {
                                        final data =
                                            doc.data() as Map<String, dynamic>;
                                        totalReceived +=
                                            (data['receivedAmount'] ?? 0)
                                                .toDouble();
                                      }
                                    }
                                    return Row(
                                      children: [
                                        const Icon(
                                          Icons.account_balance_wallet_rounded,
                                          color: Colors.white70,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Received: ₹${totalReceived.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // Events Header
              const Text(
                'Your Events',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: primaryGreen,
                ),
              ),
              const SizedBox(height: 16),

              // Filter Pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(
                  children: [
                    _buildFilterPill('All', primaryGreen),
                    _buildFilterPill('Waiting', primaryGreen),
                    _buildFilterPill('Approved', primaryGreen),
                    _buildFilterPill('Completed', primaryGreen),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Firestore Events Stream
              StreamBuilder<QuerySnapshot>(
                stream: eventsQuery.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: primaryGreen),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.inbox_rounded,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No events found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Sort client-side by createdAt descending (avoids Firestore index requirement)
                  final docs = List.from(snapshot.data!.docs)
                    ..sort((a, b) {
                      final aTs =
                          (a.data() as Map<String, dynamic>)['createdAt'];
                      final bTs =
                          (b.data() as Map<String, dynamic>)['createdAt'];
                      if (aTs == null && bTs == null) return 0;
                      if (aTs == null) return 1;
                      if (bTs == null) return -1;
                      return (bTs as Timestamp).compareTo(aTs as Timestamp);
                    });
                  return ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final id = doc.id;
                      final title = data['title'] ?? 'Untitled Event';
                      final description =
                          data['description'] ?? 'No description provided.';
                      final targetAmount = (data['targetAmount'] ?? 0)
                          .toString();
                      final status = data['status'] ?? 'Waiting';
                      // Simple parsing for timestamp
                      String date = 'N/A';
                      if (data['createdAt'] != null) {
                        final dt = (data['createdAt'] as Timestamp).toDate();
                        date = '${dt.day}/${dt.month}/${dt.year}';
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildGlassyEventCard(
                          id: id,
                          data: data,
                          title: title,
                          description: description,
                          amount: '₹$targetAmount Requested',
                          date: date,
                          status: status,
                          icon: Icons.volunteer_activism_rounded,
                          primaryGreen: primaryGreen,
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPill(String title, Color activeColor) {
    bool isSelected = _selectedFilter == title;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = title;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? activeColor : Colors.white,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          title == 'All' ? 'All' : title[0].toUpperCase() + title.substring(1),
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildGlassyEventCard({
    required String id,
    required Map<String, dynamic> data,
    required String title,
    required String description,
    required String amount,
    required String date,
    required String status,
    required IconData icon,
    required Color primaryGreen,
  }) {
    Color statusColor;
    switch (status.toLowerCase()) {
      case 'active':
      case 'approved':
        statusColor = primaryGreen;
        break;
      case 'completed':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.orange;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                DoneeEventDetailScreen(eventId: id, eventData: data),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: primaryGreen, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              date,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status.toLowerCase() == 'pending'
                              ? 'Waiting'
                              : status[0].toUpperCase() + status.substring(1),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: statusColor.withValues(alpha: 1.0),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade800,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.monetization_on_rounded,
                        size: 20,
                        color: primaryGreen,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          amount,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
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
      ), // close GestureDetector child Container
    ); // close GestureDetector
  }
}
