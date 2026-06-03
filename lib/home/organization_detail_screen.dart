// ignore_for_file: deprecated_member_use
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/organization_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qr_flutter/qr_flutter.dart';

class OrganizationDetailScreen extends StatefulWidget {
  final Organization organization;
  final Position? currentPosition;

  const OrganizationDetailScreen({
    super.key,
    required this.organization,
    this.currentPosition,
  });

  @override
  State<OrganizationDetailScreen> createState() => _OrganizationDetailScreenState();
}

class _OrganizationDetailScreenState extends State<OrganizationDetailScreen> {
  static const primaryRed  = Color(0xFFB71C1C);
  static const darkBrown   = Color(0xFF5C4033);

  // ── Glassmorphic Donation Dialog ─────────────────────────────────────────
  Future<void> _showDonationDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final amountCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Donate',
      barrierColor: Colors.black54,
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 28),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0A500).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.volunteer_activism_rounded,
                                  color: Color(0xFFF0A500), size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.organization.name,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFB71C1C)),
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text('Enter Donation Amount',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Color(0xFF5C4033))),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          autofocus: true,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: primaryRed),
                          decoration: InputDecoration(
                            prefixText: '₹  ',
                            prefixStyle: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: primaryRed),
                            hintText: '0',
                            hintStyle: TextStyle(color: Colors.grey.shade300, fontSize: 28),
                            filled: true,
                            fillColor: primaryRed.withValues(alpha: 0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          ),
                          validator: (v) {
                            final n = double.tryParse(v ?? '');
                            if (n == null || n <= 0) return 'Enter a valid amount';
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        // Quick amount chips
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [100, 500, 1000, 5000].map((amt) {
                            return GestureDetector(
                              onTap: () => amountCtrl.text = amt.toString(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0A500).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: const Color(0xFFF0A500).withValues(alpha: 0.4)),
                                ),
                                child: Text('₹$amt',
                                    style: const TextStyle(
                                        color: Color(0xFFF0A500),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                        // Buttons
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                child: const Text('Cancel',
                                    style: TextStyle(
                                        color: Color(0xFF5C4033),
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  if (!formKey.currentState!.validate()) return;
                                  Navigator.pop(ctx);
                                  await _processDonation(
                                      user, double.parse(amountCtrl.text));
                                },
                                icon: const Icon(Icons.check_circle_rounded,
                                    color: Colors.white, size: 18),
                                label: const Text('Donate Now',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFB71C1C),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
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
            ),
          ),
        );
      },
    );
  }

  Future<void> _processDonation(User user, double amount) async {
    final fs = FirebaseFirestore.instance;

    try {
      // 1. Record transaction (org donation — no eventId)
      await fs.collection('transactions').add({
        'donatorId': user.uid,
        'donatorName': user.displayName ?? 'Anonymous',
        'donatorPhoto': user.photoURL ?? '',
        'doneeId': widget.organization.id,
        'eventId': '',
        'eventTitle': widget.organization.name,
        'amount': amount,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'success',
      });

      // 2. Update donator's punyaScore + totalDonated in users collection
      final userRef = fs.collection('users').doc(user.uid);
      final userDoc = await userRef.get();
      if (userDoc.exists) {
        await userRef.update({
          'punyaScore': FieldValue.increment(amount),
          'totalDonated': FieldValue.increment(amount),
        });
      } else {
        await userRef.set({
          'punyaScore': amount,
          'totalDonated': amount,
          'name': user.displayName ?? 'Anonymous',
          'photoUrl': user.photoURL ?? '',
        }, SetOptions(merge: true));
      }

      if (mounted) {
        showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: '',
          barrierColor: Colors.black54,
          pageBuilder: (ctx, anim, secAnim) => Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB71C1C).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_circle_rounded,
                              color: Color(0xFFB71C1C), size: 56),
                        ),
                        const SizedBox(height: 20),
                        const Text('Donation Successful!',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFB71C1C))),
                        const SizedBox(height: 8),
                        Text(
                          '₹${amount.toStringAsFixed(0)} donated to ${widget.organization.name}.\nPunya score updated!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF5C4033),
                              height: 1.5),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF0A500),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Awesome!',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Donation failed: $e'), backgroundColor: const Color(0xFFB71C1C)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320.0,
            pinned: true,
            backgroundColor: primaryRed,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16, right: 16),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  widget.organization.imageUrl.startsWith('http')
                      ? Image.network(
                          widget.organization.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
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
                            Icons.account_balance_rounded,
                            size: 80,
                            color: Colors.white24,
                          ),
                        ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'title-${widget.organization.id}',
                    child: Material(
                      type: MaterialType.transparency,
                      child: Text(
                        widget.organization.name,
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                            height: 1.1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0A500).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFF0A500).withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          widget.organization.category.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFF0A500)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.location_on_rounded,
                          size: 16, color: primaryRed),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.organization.locationName,
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Funds Raised red card (live stream) ─────────────
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('transactions')
                        .where('doneeId', isEqualTo: widget.organization.id)
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
                                  '₹${total.toStringAsFixed(0)}',
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
                                    'from $count donor${count == 1 ? '' : 's'}',
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
                                value: count == 0 ? 0.0 : 1.0,
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
                              count == 0
                                  ? 'Be the first to donate!'
                                  : '$count donation${count == 1 ? '' : 's'} received',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // ── Info cards (location + verified) ────────────────
                  Row(
                    children: [
                      _buildInfoCard(
                        Icons.location_on_rounded,
                        widget.organization.locationName.isNotEmpty
                            ? widget.organization.locationName
                            : 'Location N/A',
                        'Organisation location',
                      ),
                      const SizedBox(width: 12),
                      _buildInfoCard(
                        Icons.verified_rounded,
                        'Verified',
                        'Community Trust',
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  const Text('About this place',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryRed)),
                  const SizedBox(height: 12),

                  Text(
                    widget.organization.description,
                    style: const TextStyle(
                        fontSize: 15,
                        color: darkBrown,
                        height: 1.5,
                        letterSpacing: 0.2),
                  ),

                  const SizedBox(height: 32),

                  const Text('Scan to Share',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryRed)),
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: 'https://punyadaan-e0972.web.app/org/${widget.organization.id}',
                        version: QrVersions.auto,
                        size: 200.0,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SizedBox(
          height: 60,
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _showDonationDialog,
            icon: const Icon(Icons.volunteer_activism_rounded,
                color: Colors.white),
            label: const Text(
              'Donate Now',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB71C1C),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              elevation: 6,
              shadowColor: primaryRed.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String title, String subtitle) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFFF0A500), size: 24),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF5C4033)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(color: darkBrown, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
