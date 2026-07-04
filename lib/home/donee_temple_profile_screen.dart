// ignore_for_file: deprecated_member_use
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/organization_model.dart';

class DoneeTempleProfileScreen extends StatelessWidget {
  final Organization organization;

  const DoneeTempleProfileScreen({super.key, required this.organization});

  static const primaryRed  = Color(0xFFB71C1C);
  static const darkBrown   = Color(0xFF5C4033);
  static const pillYellow  = Color(0xFFF0A500);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero image ───────────────────────────────────────────────
          Stack(
            children: [
              SizedBox(
                height: 250,
                width: double.infinity,
                child: organization.imageUrl.startsWith('http')
                    ? Image.network(organization.imageUrl, fit: BoxFit.cover)
                    : Container(color: Colors.grey.shade300),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 20,
                right: 20,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: organization.status == 'approved'
                                  ? const Color(0xFF388E3C).withValues(alpha: 0.9)
                                  : pillYellow.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              organization.status?.toUpperCase() ?? 'WAITING',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            organization.name,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFB71C1C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 16,
                      color: pillYellow,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        organization.locationName,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF5C4033),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // About
                const Text(
                  'About',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB71C1C),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  organization.description,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF5C4033),
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 32),

                // ── Live total received ────────────────────────────────
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('transactions')
                      .where('doneeId', isEqualTo: organization.id)
                      .snapshots(),
                  builder: (context, snap) {
                    double total = 0;
                    int count = 0;
                    if (snap.hasData) {
                      for (var doc in snap.data!.docs) {
                        final d = doc.data() as Map<String, dynamic>;
                        total += (d['amount'] ?? 0) as num;
                        count++;
                      }
                    }
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Color(0xFFB71C1C).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Color(0xFFB71C1C).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statItem(
                            Icons.account_balance_wallet_rounded,
                            '₹${total.toStringAsFixed(0)}',
                            'Total Received',
                            primaryRed,
                          ),
                          Container(
                            width: 1,
                            height: 36,
                            color: Color(0xFFB71C1C).withValues(alpha: 0.2),
                          ),
                          _statItem(
                            Icons.people_alt_rounded,
                            '$count',
                            'Donors',
                            const Color(0xFF5C4033),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 32),

                // ── QR Code ────────────────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Your ${_categoryDisplayName(organization.category)} QR Code',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB71C1C),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Donators can scan this to view and donate',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF5C4033),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: organization.status == 'approved'
                            ? QrImageView(
                                data:
                                    'https://punyadaan-e0972.web.app/org/${organization.id}',
                                version: QrVersions.auto,
                                size: 200.0,
                                backgroundColor: Colors.white,
                              )
                            : Container(
                                height: 200,
                                width: 200,
                                alignment: Alignment.center,
                                child: const Text(
                                  'QR Code hidden until approved',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // ── Real Transactions ──────────────────────────────────
                const Text(
                  'Recent Transactions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB71C1C),
                  ),
                ),
                const SizedBox(height: 16),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('transactions')
                      .where('doneeId', isEqualTo: organization.id)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: primaryRed),
                      );
                    }

                    if (!snap.hasData || snap.data!.docs.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
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
                              'Donations will appear here in real-time',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Sort client-side newest first (no composite index needed)
                    final docs = List.from(snap.data!.docs)
                      ..sort((a, b) {
                        final aTs =
                            (a.data() as Map<String, dynamic>)['createdAt']
                                as Timestamp?;
                        final bTs =
                            (b.data() as Map<String, dynamic>)['createdAt']
                                as Timestamp?;
                        if (aTs == null && bTs == null) return 0;
                        if (aTs == null) return 1;
                        if (bTs == null) return -1;
                        return bTs.compareTo(aTs);
                      });

                    return Column(
                      children: docs.map((doc) {
                        final d = doc.data() as Map<String, dynamic>;
                        final donorName = d['donatorName'] ?? 'Anonymous';
                        final amount = (d['amount'] ?? 0) as num;
                        final ts = d['createdAt'] as Timestamp?;
                        final photoUrl = d['donatorPhoto'] as String? ?? '';

                        String dateStr = 'Just now';
                        if (ts != null) {
                          final dt = ts.toDate();
                          final now = DateTime.now();
                          final diff = now.difference(dt);
                          if (diff.inMinutes < 1) {
                            dateStr = 'Just now';
                          } else if (diff.inHours < 1) {
                            dateStr = '${diff.inMinutes}m ago';
                          } else if (diff.inDays < 1) {
                            dateStr = '${diff.inHours}h ago';
                          } else if (diff.inDays == 1) {
                            dateStr =
                                'Yesterday, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                          } else {
                            dateStr =
                                '${dt.day} ${_month(dt.month)}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                          }
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
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
                          child: Row(
                            children: [
                              // Avatar
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: primaryRed.withValues(
                                  alpha: 0.1,
                                ),
                                backgroundImage: photoUrl.isNotEmpty
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(
    IconData icon,
    String value,
    String label,
    Color valueColor,
  ) {
    return Column(
      children: [
        Icon(icon, color: pillYellow, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF5C4033),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _month(int m) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[m - 1];
  }

  /// Maps Firestore category → human-readable display name
  String _categoryDisplayName(String category) {
    switch (category) {
      case 'Temple':
        return 'Religious Place';
      case 'Gaushala':
        return 'Gaushala';
      case 'Charity':
        return 'Charity Organisation';
      case 'Yogdaan':
        return 'Yogdaan';
      default:
        return category;
    }
  }
}
