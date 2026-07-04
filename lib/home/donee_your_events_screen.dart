import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'donee_event_detail_screen.dart';
import 'donee_create_event_screen.dart';
import 'event_screen.dart'; // Donator event creation form

class DoneeYourEventsScreen extends StatefulWidget {
  /// When [showCreateButton] is true an "+ Create Event" action appears in the
  /// AppBar (used when embedded in the Donator home's Event tab).
  /// Set [isDonator] to true when this screen is used inside the donator home
  /// so the FAB routes to the correct (donator) event creation form.
  const DoneeYourEventsScreen({
    super.key,
    this.showCreateButton = false,
    this.isDonator = false,
  });

  final bool showCreateButton;
  final bool isDonator;

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

    // Donators save events with 'donatorId'; donees use 'doneeId'
    Query<Map<String, dynamic>> eventsQuery = FirebaseFirestore.instance
        .collection('events')
        .where(
          widget.isDonator ? 'donatorId' : 'doneeId',
          isEqualTo: user?.uid ?? '',
        );

    if (_selectedFilter != 'All') {
      final fsStatus =
          _filterToStatus[_selectedFilter] ?? _selectedFilter.toLowerCase();
      eventsQuery = eventsQuery.where('status', isEqualTo: fsStatus);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Your Events',
          style: TextStyle(
            color: Color(0xFFF0A500),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFF0A500)),
      ),
      floatingActionButton: widget.showCreateButton
          ? Padding(
              padding: const EdgeInsets.only(bottom: 88),
              child: FloatingActionButton.extended(
                onPressed: () {
                  if (widget.isDonator) {
                    // Donator → use the donator-specific event creation form
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const Scaffold(
                          backgroundColor: Color(0xFFF6F8FD),
                          body: SafeArea(child: EventScreen()),
                        ),
                      ),
                    );
                  } else {
                    // Donee → use the donee event creation form
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const _CreateEventPage(),
                      ),
                    );
                  }
                },
                backgroundColor: const Color(0xFFB71C1C),
                foregroundColor: Colors.white,
                elevation: 4,
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'Create Event',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
                      color: const Color.fromARGB(
                        255,
                        197,
                        30,
                        30,
                      ).withValues(alpha: 0.2),
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

              const SizedBox(height: 40),

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
          color: isSelected
              ? const Color(0xFFB71C1C)
              : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? const Color(0xFFB71C1C) : Colors.white,
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
            color: isSelected ? Colors.white : const Color(0xFF5C4033),
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
                          color: const Color(
                            0xFFF0A500,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          icon,
                          color: const Color(0xFFF0A500),
                          size: 28,
                        ),
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
                                color: Color(0xFF5C4033),
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
                          color: const Color(
                            0xFFF0A500,
                          ).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status.toLowerCase() == 'pending'
                              ? 'Waiting'
                              : status[0].toUpperCase() + status.substring(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF0A500),
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
                      Image.asset(
                        'assets/home/coin.png',
                        width: 45,
                        height: 45,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          amount,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF24963F),
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

/// A standalone page that wraps [DoneeCreateEventScreen] with no AppBar,
/// navigated to when the user taps "+ Create Event" from the Your Events page.
class _CreateEventPage extends StatelessWidget {
  const _CreateEventPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF6F8FD),
      body: SafeArea(child: DoneeCreateEventScreen()),
    );
  }
}
