import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'add_organization_screen.dart';
import '../models/organization_model.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // 0: Pending Events, 1: Approved Events, 2: Users, 3: Orgs, 4: Deactivations
  int _currentIndex = 0;

  Future<void> _signOut() async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
    }
  }

  void _confirmSignOut() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
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
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 32),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Sign Out?',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Are you sure you want to log out of the admin dashboard?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.black54,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _signOut();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
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

  void _showEventDetails(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      child: Image.network(
                        data['imageUrl'],
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 50),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['title'] ?? data['name'] ?? 'Unnamed Event',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF24963F).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                data['category'] ?? 'General',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF24963F),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '₹${data['targetAmount'] ?? 0}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.date_range_rounded, size: 16, color: Colors.black54),
                            const SizedBox(width: 6),
                            Text(data['date'] ?? 'N/A', style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.person_rounded, size: 16, color: Colors.black54),
                            const SizedBox(width: 6),
                            Text('Created By: ${data['creatorName'] ?? 'Unknown'}', style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data['description'] ?? 'No description provided.',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: Colors.black12),
                            ),
                            child: const Text('Close', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _updateEventStatus(String eventId, String newStatus) async {
    await FirebaseFirestore.instance.collection('events').doc(eventId).update({
      'status': newStatus,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Event marked as $newStatus')));
    }
  }

  void _deleteEvent(String eventId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Event?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
            'This action is permanent and cannot be undone. Are you sure you want to delete this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance
                  .collection('events')
                  .doc(eventId)
                  .delete();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Event deleted.')));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB71C1C),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _toggleUserBlock(String uid, bool currentBlockStatus) async {
    // Standard users might not have isBlocked natively configured yet, using set with merge
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'isBlocked': !currentBlockStatus,
    }, SetOptions(merge: true));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User ${!currentBlockStatus ? "blocked" : "unblocked"}')));
    }
  }

  void _deleteOrganization(String orgId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Organisation?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
            'This action is permanent and cannot be undone. Are you sure you want to delete this organisation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance
                  .collection('organizations')
                  .doc(orgId)
                  .delete();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Organisation deleted.')));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB71C1C),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _updateOrganizationStatus(String orgId, String newStatus) async {
    await FirebaseFirestore.instance.collection('organizations').doc(orgId).update({
      'status': newStatus,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Organization marked as $newStatus')));
    }
  }

  // ── Approved organizations tab ─────────────────────────────────────
  Widget _buildApprovedOrganizationsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('organizations')
          .where('status', isEqualTo: 'approved')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No approved organizations yet.'));
        }

        final docs = snapshot.data!.docs;
        final orgs = docs.map((doc) => Organization.fromFirestore(doc)).toList();

        return ListView.builder(
          itemCount: orgs.length,
          itemBuilder: (context, index) {
            final org = orgs[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: org.imageUrl.isNotEmpty
                    ? Image.network(org.imageUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.location_city))
                    : const Icon(Icons.location_city),
                title: Text(org.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    'Category: ${org.category.toUpperCase()}\nLoc: ${org.locationName}'),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  AddOrganizationScreen(existingOrg: org))),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteOrganization(org.id),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Merged Waiting tab (pending events + pending orgs) ─────────────
  Widget _buildWaitingTab() {
    final pendingEventsStream = FirebaseFirestore.instance
        .collection('events')
        .where('status', isEqualTo: 'pending')
        .snapshots();

    final pendingOrgsStream = FirebaseFirestore.instance
        .collection('organizations')
        .where('status', isEqualTo: 'pending')
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: pendingEventsStream,
      builder: (context, eventSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: pendingOrgsStream,
          builder: (context, orgSnap) {
            if (eventSnap.connectionState == ConnectionState.waiting ||
                orgSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Build unified item list: type + doc
            final List<Map<String, dynamic>> items = [];

            if (eventSnap.hasData) {
              for (final doc in eventSnap.data!.docs) {
                items.add({'type': 'event', 'doc': doc});
              }
            }
            if (orgSnap.hasData) {
              for (final doc in orgSnap.data!.docs) {
                items.add({'type': 'org', 'doc': doc});
              }
            }

            if (items.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.done_all_rounded,
                        size: 56, color: Color(0xFF24963F)),
                    SizedBox(height: 12),
                    Text('All clear! Nothing pending.',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF24963F))),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                if (item['type'] == 'event') {
                  return _buildWaitingEventCard(item['doc']);
                } else {
                  return _buildWaitingOrgCard(item['doc']);
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildWaitingEventCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final creatorType = data['creatorType'] as String? ?? 'donator';
    final isDonator = creatorType == 'donator';
    final badgeLabel = isDonator ? 'Donator Event' : 'Donee Event';
    final badgeColor =
        isDonator ? const Color(0xFF24963F) : const Color(0xFF1565C0);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        onTap: () => _showEventDetails(data),
        leading: data['imageUrl'] != null
            ? Image.network(data['imageUrl'],
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.event))
            : const Icon(Icons.event),
        title: Row(
          children: [
            Expanded(
                child: Text(data['title'] ?? data['name'] ?? 'Unnamed Event',
                    style:
                        const TextStyle(fontWeight: FontWeight.bold))),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(badgeLabel,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: badgeColor)),
            ),
          ],
        ),
        subtitle: Text(
            'Date: ${data['date'] ?? 'N/A'}\nBy: ${data['creatorName'] ?? 'Unknown'}'),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              onPressed: () => _updateEventStatus(doc.id, 'approved'),
              tooltip: 'Approve',
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              onPressed: () => _updateEventStatus(doc.id, 'declined'),
              tooltip: 'Reject',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingOrgCard(QueryDocumentSnapshot doc) {
    final org = Organization.fromFirestore(doc);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: org.imageUrl.isNotEmpty
            ? Image.network(org.imageUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.location_city))
            : const Icon(Icons.location_city),
        title: Row(
          children: [
            Expanded(
                child: Text(org.name,
                    style:
                        const TextStyle(fontWeight: FontWeight.bold))),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF0A500).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Organisation',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF0A500))),
            ),
          ],
        ),
        subtitle: Text(
            'Category: ${org.category.toUpperCase()}\nLoc: ${org.locationName}'),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              onPressed: () =>
                  _updateOrganizationStatus(org.id, 'approved'),
              tooltip: 'Approve',
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              onPressed: () =>
                  _updateOrganizationStatus(org.id, 'rejected'),
              tooltip: 'Reject',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteOrganization(org.id),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('events').where('status', isEqualTo: status).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No $status events found.'));
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>? ?? {};
            
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                onTap: () => _showEventDetails(data),
                leading: data['imageUrl'] != null 
                    ? Image.network(data['imageUrl'], width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.event))
                    : const Icon(Icons.event),
                title: Text(data['name'] ?? 'Unnamed Event', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Date: ${data['date'] ?? 'N/A'}\nBy User: ${data['creatorName'] ?? 'Unknown'}'),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: status == 'pending' 
                      ? [
                          IconButton(
                            icon: const Icon(Icons.check_circle, color: Colors.green),
                            onPressed: () => _updateEventStatus(doc.id, 'approved'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            onPressed: () => _updateEventStatus(doc.id, 'declined'),
                          ),
                        ]
                      : [
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteEvent(doc.id),
                          ),
                        ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  Widget _buildUsersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No users found.'));
        }

        final docs = snapshot.data!.docs.where((doc) => doc.id != FirebaseAuth.instance.currentUser?.uid).toList();
        
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final bool isBlocked = data['isBlocked'] ?? false;
            
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(data['name'] ?? 'Unnamed User'),
                subtitle: Text('Email: ${data['email'] ?? 'N/A'} | Role: ${data['role'] ?? 'None'}'),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBlocked ? Colors.green : Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _toggleUserBlock(doc.id, isBlocked),
                  child: Text(isBlocked ? 'Unblock' : 'Block'),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Deactivation Requests Tab ─────────────────────────────────
  Widget _buildDeactivationRequests() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('deactivation_requests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.how_to_reg_rounded,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('No pending deactivation requests.',
                    style: TextStyle(
                        fontSize: 15, color: Colors.grey.shade500)),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final role = data['role'] as String? ?? 'unknown';
            final isDonator = role == 'donator';
            final ts = data['requestedAt'] as Timestamp?;
            final requestDate = ts != null
                ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year}'
                : 'Unknown date';

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Avatar icon
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDonator
                                ? const Color(0xFF24963F).withValues(alpha: 0.1)
                                : const Color(0xFF1565C0).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_rounded,
                            color: isDonator
                                ? const Color(0xFF24963F)
                                : const Color(0xFF1565C0),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Name & email
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['displayName'] ?? 'Unknown User',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                data['email'] ?? '',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        // Role badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDonator
                                ? const Color(0xFF24963F).withValues(alpha: 0.1)
                                : const Color(0xFF1565C0).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDonator
                                  ? const Color(0xFF24963F).withValues(alpha: 0.4)
                                  : const Color(0xFF1565C0).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isDonator
                                    ? Icons.volunteer_activism_rounded
                                    : Icons.temple_hindu_rounded,
                                size: 12,
                                color: isDonator
                                    ? const Color(0xFF24963F)
                                    : const Color(0xFF1565C0),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isDonator ? 'Donator' : 'Donee',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDonator
                                      ? const Color(0xFF24963F)
                                      : const Color(0xFF1565C0),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Request date
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 13, color: Colors.grey.shade500),
                        const SizedBox(width: 6),
                        Text(
                          'Requested on $requestDate',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    // Approve / Reject buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              // Reject
                              final messenger = ScaffoldMessenger.of(context);
                              await FirebaseFirestore.instance
                                  .collection('deactivation_requests')
                                  .doc(doc.id)
                                  .update({'status': 'rejected'});
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(doc.id)
                                  .update({'deactivationStatus': 'none'});
                              if (mounted) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Request rejected.')));
                              }
                            },
                            icon: const Icon(Icons.close_rounded,
                                size: 16, color: Colors.redAccent),
                            label: const Text('Reject',
                                style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w700)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: Colors.redAccent, width: 1.2),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              // Approve — set deactivateAt 12 days from now
                              final messenger = ScaffoldMessenger.of(context);
                              final now = DateTime.now();
                              final deactivateAt =
                                  now.add(const Duration(days: 12));
                              final nowTs = Timestamp.now();
                              final deactivateTs =
                                  Timestamp.fromDate(deactivateAt);

                              await FirebaseFirestore.instance
                                  .collection('deactivation_requests')
                                  .doc(doc.id)
                                  .update({
                                'status': 'approved',
                                'approvedAt': nowTs,
                                'deactivateAt': deactivateTs,
                              });
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(doc.id)
                                  .update({
                                'deactivationStatus': 'approved',
                                'deactivateAt': deactivateTs,
                              });
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Approved. Account deactivates on ${deactivateAt.day}/${deactivateAt.month}/${deactivateAt.year}.'),
                                    backgroundColor: const Color(0xFF24963F),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.check_rounded,
                                size: 16, color: Colors.white),
                            label: const Text('Approve',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF24963F),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        automaticallyImplyLeading: false, // Prevents generic back routing from polluting the security bounds
        title: const Text('Admin Dashboard', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_rounded, color: Colors.black87),
            tooltip: 'Add Organization via Admin',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddOrganizationScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black87),
            tooltip: 'Sign Out Admin',
            onPressed: _confirmSignOut,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildWaitingTab(),           // 0: Waiting (pending events + pending orgs)
          _buildEventsList('approved'), // 1: Events (approved events)
          _buildApprovedOrganizationsList(), // 2: Organisations (approved orgs)
          _buildUsersList(),            // 3: Users
          _buildDeactivationRequests(), // 4: Deactivations
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: const Color(0xFF24963F),
        unselectedItemColor: Colors.grey.shade500,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.pending_actions), label: 'Waiting'),
          BottomNavigationBarItem(
              icon: Icon(Icons.event_available), label: 'Events'),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance), label: 'Organisations'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Users'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_off_rounded), label: 'Deactivations'),
        ],
      ),
    );
  }
}
