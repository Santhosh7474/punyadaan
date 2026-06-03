// ignore_for_file: deprecated_member_use
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class DoneeEventDetailScreen extends StatelessWidget {
  final String eventId;
  final Map<String, dynamic> eventData;

  const DoneeEventDetailScreen({
    super.key,
    required this.eventId,
    required this.eventData,
  });

  // ── Brand palette ────────────────────────────────────────────────────
  static const primaryRed  = Color(0xFFB71C1C);
  static const darkBrown   = Color(0xFF5C4033);
  static const pillYellow  = Color(0xFFF0A500);

  String _formatRelativeDate(Timestamp? ts) {
    if (ts == null) return 'Just now';
    final dt = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) {
      return 'Yesterday, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]}, '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .snapshots(),
      builder: (context, snapshot) {
        // Use live data from Firestore, fall back to passed-in data
        final data = (snapshot.hasData && snapshot.data!.exists)
            ? (snapshot.data!.data() as Map<String, dynamic>)
            : eventData;

        final title = data['title'] ?? 'Untitled Event';
        final description = data['description'] ?? '';
        final category = data['category'] ?? 'General';
        final location = data['location'] as String? ?? '';
        final imageUrl = data['imageUrl'] as String? ?? '';
        final targetAmount = (data['targetAmount'] ?? 0) as num;
        final receivedAmount = (data['receivedAmount'] ?? 0) as num;
        final status = data['status'] ?? 'pending';
        final createdAtTs = data['createdAt'] as Timestamp?;
        final date = data['date'] as String? ?? '';

        final double target = targetAmount.toDouble();
        final double received = receivedAmount.toDouble();
        final double progress =
            target > 0 ? (received / target).clamp(0.0, 1.0) : 0.0;

        // Status badge color
        Color statusColor;
        String statusLabel;
        switch (status.toLowerCase()) {
          case 'approved':
            statusColor = const Color(0xFF388E3C);
            statusLabel = 'Approved';
            break;
          case 'completed':
            statusColor = Colors.blue.shade700;
            statusLabel = 'Completed';
            break;
          default:
            statusColor = pillYellow;
            statusLabel = 'Waiting';
        }

        String createdOn = '';
        if (createdAtTs != null) {
          final dt = createdAtTs.toDate();
          createdOn = '${dt.day}/${dt.month}/${dt.year}';
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF7F7F7),
          body: CustomScrollView(
            slivers: [
              // ── Hero AppBar ─────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                backgroundColor: primaryRed,
                iconTheme: const IconThemeData(color: Colors.white),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      imageUrl.startsWith('http')
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [primaryRed, Color(0xFF8B0000)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [primaryRed, Color(0xFF8B0000)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Icon(
                                Icons.event_rounded,
                                size: 80,
                                color: Colors.white24,
                              ),
                            ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.65),
                            ],
                          ),
                        ),
                      ),
                      // Status badge overlay
                      Positioned(
                        bottom: 20,
                        left: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            statusLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Title & Category ────────────────────────────
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          // Yellow pill for category
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: pillYellow.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: pillYellow.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Text(
                              category.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: pillYellow,
                              ),
                            ),
                          ),
                          if (createdOn.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 13,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Created $createdOn',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ── Funding Progress Card ────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [primaryRed, Color(0xFF8B0000)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: primaryRed.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Funds Raised',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${received.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    'of ₹${target.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.25),
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${(progress * 100).toStringAsFixed(0)}% of goal reached',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Info Grid ───────────────────────────────────
                      Row(
                        children: [
                          _infoCard(
                            Icons.location_on_rounded,
                            location.isNotEmpty ? location : 'Not specified',
                            'Location',
                          ),
                          const SizedBox(width: 12),
                          _infoCard(
                            Icons.event_rounded,
                            date.isNotEmpty ? date : 'Not set',
                            'Event Date',
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // ── Description ─────────────────────────────────
                      const Text(
                        'About this Event',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryRed,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        description.isNotEmpty
                            ? description
                            : 'No description provided.',
                        style: const TextStyle(
                          fontSize: 15,
                          color: darkBrown,
                          height: 1.6,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── QR Code ─────────────────────────────────────
                      if (status.toLowerCase() == 'approved') ...[
                        const Text(
                          'Event QR Code',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryRed,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Donators can scan this to donate directly',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: QrImageView(
                              data:
                                  'https://punyadaan-e0972.web.app/event/$eventId',
                              version: QrVersions.auto,
                              size: 180.0,
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // ── Donations Received (Donee-only) ─────────────
                      const Text(
                        'Donations Received',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryRed,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Real-time donor activity for this event',
                        style: TextStyle(fontSize: 12, color: darkBrown),
                      ),
                      const SizedBox(height: 14),

                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('transactions')
                            .where('eventId', isEqualTo: eventId)
                            .snapshots(),
                        builder: (context, snap) {
                          if (snap.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: primaryRed,
                              ),
                            );
                          }

                          if (!snap.hasData || snap.data!.docs.isEmpty) {
                            return Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 32),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey.shade100,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.inbox_rounded,
                                    size: 48,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No donations yet',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Donations appear here in real-time',
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          // Client-side sort newest first
                          final docs = List.from(snap.data!.docs)
                            ..sort((a, b) {
                              final aTs =
                                  (a.data() as Map<String, dynamic>)[
                                        'createdAt'
                                      ] as Timestamp?;
                              final bTs =
                                  (b.data() as Map<String, dynamic>)[
                                        'createdAt'
                                      ] as Timestamp?;
                              if (aTs == null && bTs == null) return 0;
                              if (aTs == null) return 1;
                              if (bTs == null) return -1;
                              return bTs.compareTo(aTs);
                            });

                          return Column(
                            children: docs.map((doc) {
                              final d =
                                  doc.data() as Map<String, dynamic>;
                              final donorName =
                                  d['donatorName'] ?? 'Anonymous';
                              final amount = (d['amount'] ?? 0) as num;
                              final photoUrl =
                                  d['donatorPhoto'] as String? ?? '';
                              final dateStr = _formatRelativeDate(
                                d['createdAt'] as Timestamp?,
                              );

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.grey.shade100,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.03,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: primaryRed.withValues(
                                        alpha: 0.1,
                                      ),
                                      backgroundImage:
                                          photoUrl.isNotEmpty
                                              ? NetworkImage(photoUrl)
                                              : null,
                                      child: photoUrl.isEmpty
                                          ? const Icon(
                                              Icons.person_rounded,
                                              color: primaryRed,
                                              size: 22,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            donorName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            dateStr,
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '+₹${amount.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: primaryRed,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoCard(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: pillYellow, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: darkBrown),
            ),
          ],
        ),
      ),
    );
  }
}
