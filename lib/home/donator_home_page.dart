import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:app_links/app_links.dart';
import '../profile/profile_page.dart';
import '../services/permission_service.dart';
import '../services/fcm_service.dart';
import 'notifications_screen.dart';
import 'scanner_screen.dart';
import 'donee_your_events_screen.dart';
import 'category_all_screen.dart';
import 'organization_detail_screen.dart';
import '../models/organization_model.dart';
import 'all_donators_screen.dart';
import 'event_detail_screen.dart';
import 'transactions_screen.dart';
import '../profile/payment_settings_screen.dart';

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({super.key});

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  double _navOpacity = 0.95; // Initial solid look
  int _searchHighlightIndex = 0;
  final List<String> _searchHighlights = [
    'temples',
    'charity',
    'Gaushala',
    'Kanyadaan',
  ];
  Timer? _searchTimer;
  int _currentNavIndex = 0; // 0: Home, 1: Event, 2: Scan, 3: Transactions

  String _currentLocation = 'Fetching...';
  Position? _currentPosition; // Explicitly maintaining live geographic status
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isListening = false;

  // Cached specific streams bypassing UI render flickers explicitly limiting generic footprint to 3 documents statically locally!
  late final Stream<QuerySnapshot> _orgTempleStream;
  late final Stream<QuerySnapshot> _orgGaushalaStream;
  late final Stream<QuerySnapshot> _orgCharityStream;
  late final Stream<QuerySnapshot> _orgKanyadaanStream;
  late final Stream<QuerySnapshot> _orgYogdaanStream;
  late final Stream<QuerySnapshot> _eventTempleStream;
  late final Stream<QuerySnapshot> _eventGaushalaStream;
  late final Stream<QuerySnapshot> _eventCharityStream;
  late final Stream<QuerySnapshot> _eventKanyadaanStream;
  late final Stream<QuerySnapshot> _eventYogdaanStream;

  // Cached real-time stream for top donators — cached so parent setStates don't recreate it.
  late final Stream<QuerySnapshot> _topDonatorsStream;

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _speechToText.initialize();

    // Request all permissions one-by-one AFTER login (not at splash)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        PermissionService.requestAllPermissions(context);
        FCMService.init(); // Initialize FCM and save token to Firestore
      }
    });
    _orgTempleStream = FirebaseFirestore.instance
        .collection('organizations')
        .where('status', isEqualTo: 'approved')
        .where('category', whereIn: ['Temple', 'temple'])
        .limit(3)
        .snapshots();
    _orgGaushalaStream = FirebaseFirestore.instance
        .collection('organizations')
        .where('status', isEqualTo: 'approved')
        .where('category', whereIn: ['Gaushala', 'gaushala'])
        .limit(3)
        .snapshots();
    _orgCharityStream = FirebaseFirestore.instance
        .collection('organizations')
        .where('status', isEqualTo: 'approved')
        .where('category', whereIn: ['Charity', 'charity'])
        .limit(3)
        .snapshots();
    _orgKanyadaanStream = FirebaseFirestore.instance
        .collection('organizations')
        .where('status', isEqualTo: 'approved')
        .where('category', whereIn: ['Kanyadaan', 'kanyadaan'])
        .limit(3)
        .snapshots();

    _eventTempleStream = FirebaseFirestore.instance
        .collection('events')
        .where('status', isEqualTo: 'approved')
        .where('category', whereIn: ['Temple', 'temple'])
        .limit(3)
        .snapshots();
    _eventGaushalaStream = FirebaseFirestore.instance
        .collection('events')
        .where('status', isEqualTo: 'approved')
        .where('category', whereIn: ['Gaushala', 'gaushala'])
        .limit(3)
        .snapshots();
    _eventCharityStream = FirebaseFirestore.instance
        .collection('events')
        .where('status', isEqualTo: 'approved')
        .where('category', whereIn: ['Charity', 'charity'])
        .limit(3)
        .snapshots();
    _eventKanyadaanStream = FirebaseFirestore.instance
        .collection('events')
        .where('status', isEqualTo: 'approved')
        .where('category', whereIn: ['Kanyadaan', 'kanyadaan'])
        .limit(3)
        .snapshots();
    _orgYogdaanStream = FirebaseFirestore.instance
        .collection('organizations')
        .where('status', isEqualTo: 'approved')
        .where('category', whereIn: ['Yogdaan', 'yogdaan'])
        .limit(3)
        .snapshots();
    _eventYogdaanStream = FirebaseFirestore.instance
        .collection('events')
        .where('status', isEqualTo: 'approved')
        .where('category', whereIn: ['Yogdaan', 'yogdaan'])
        .limit(3)
        .snapshots();

    _topDonatorsStream = FirebaseFirestore.instance
        .collection('users')
        .snapshots();

    _searchController.addListener(() {
      setState(() {}); // Rebuild to show/hide search results
    });

    // Quick automated schema migration to handle older organizations that lack a 'status' field natively.
    FirebaseFirestore.instance.collection('organizations').get().then((
      snapshot,
    ) {
      for (var doc in snapshot.docs) {
        if (!doc.data().containsKey('status')) {
          doc.reference.update({'status': 'approved'});
        }
      }
    });

    _scrollController.addListener(_onScroll);
    _searchTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _searchHighlightIndex =
              (_searchHighlightIndex + 1) % _searchHighlights.length;
        });
      }
    });

    _initDeepLinks();
  }


  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Handle link when app is in background/foreground
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });

    // Handle initial link if app was closed
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleDeepLink(initialUri);
        });
      }
    } catch (e) {
      debugPrint('Failed to get initial deep link: $e');
    }
  }

  void _handleDeepLink(Uri uri) async {
    final path = uri.path; // e.g. "/org/123"
    if (path.startsWith('/org/')) {
      final orgId = path.replaceAll('/org/', '');

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF24963F)),
        ),
      );

      try {
        final doc = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(orgId)
            .get();
        if (!mounted) return;
        Navigator.pop(context); // hide loading
        if (doc.exists) {
          final org = Organization.fromFirestore(doc);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrganizationDetailScreen(
                organization: org,
                currentPosition: _currentPosition,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Organization not found.')),
          );
        }
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // hide loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Deep link error: $e')));
      }
    }
  }

  void _onScroll() {
    double offset = _scrollController.offset;
    // Map offset 0 -> 100 to opacity 0.95 -> 0.6
    double newOpacity = 0.95 - (offset / 100) * 0.35;
    newOpacity = newOpacity.clamp(0.6, 0.95);
    if (newOpacity != _navOpacity) {
      setState(() {
        _navOpacity = newOpacity;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchTimer?.cancel();
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _currentLocation = 'Location Disabled');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _currentLocation = 'Permission Denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _currentLocation = 'Permission Denied');
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
          if (placemarks.isNotEmpty) {
            _currentLocation = placemarks.first.locality ?? 'Unknown Location';
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _currentLocation = 'Location Error');
    }
  }

  void _listenToSpeech() async {
    if (!_isListening) {
      bool available = await _speechToText.initialize(
        onStatus: (val) {
          if (val == 'done' && mounted) {
            setState(() => _isListening = false);
          }
        },
        onError: (val) {
          debugPrint('onError: $val');
          if (mounted) setState(() => _isListening = false);
        },
      );
      if (available && mounted) {
        setState(() => _isListening = true);
        _speechToText.listen(
          onResult: (val) => setState(() {
            _searchController.text = val.recognizedWords;
          }),
        );
      }
    } else {
      if (mounted) setState(() => _isListening = false);
      _speechToText.stop();
    }
  }

  Widget _buildCarouselCard(Widget child, {String? imageUrl}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB71C1C).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: BoxDecoration(
              gradient: imageUrl == null
                  ? const LinearGradient(
                      colors: [Color(0xFFB71C1C), Color(0xFF7B0000)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              image: imageUrl != null && imageUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withValues(alpha: 0.6),
                        BlendMode.darken,
                      ),
                    )
                  : null,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1.2,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildPunyaScoreContent() {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid ?? '')
          .snapshots(),
      builder: (context, snap) {
        final data = (snap.hasData && snap.data!.exists)
            ? (snap.data!.data() as Map<String, dynamic>)
            : <String, dynamic>{};
        final score = (data['punyaScore'] ?? 0) as num;
        final totalDonated = (data['totalDonated'] ?? 0) as num;
        final upiId =
            (data['payment'] as Map<String, dynamic>?)?['upiId'] as String? ??
            '';

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Punya Score
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Punya Score',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    score.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.volunteer_activism_rounded,
                        color: Colors.white70,
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '₹${totalDonated.toStringAsFixed(0)} Donated',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Divider
            Container(
              width: 1,
              height: 70,
              color: Colors.white24,
              margin: const EdgeInsets.symmetric(horizontal: 12),
            ),
            // Right: Wallet
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white70,
                        size: 13,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'My Wallet',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    upiId.isNotEmpty ? upiId : 'No UPI linked',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: upiId.isNotEmpty ? Colors.white : Colors.white38,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PaymentSettingsScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Manage',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentDonations() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('donatorId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink(); // Hidden when no donations
        }

        // Sort client-side by createdAt desc, take max 3
        final docs = List.from(snap.data!.docs)
          ..sort((a, b) {
            final aTs =
                (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            final bTs =
                (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            if (aTs == null && bTs == null) return 0;
            if (aTs == null) return 1;
            if (bTs == null) return -1;
            return bTs.compareTo(aTs);
          });
        final recent = docs.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 22,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0A500),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Text(
                      'Recent Donations',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFB71C1C),
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => setState(() => _currentNavIndex = 3),
                  child: const Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF0A500),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Transaction cards
            ...recent.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final title = data['eventTitle'] ?? 'Unnamed Event';
              final amount = (data['amount'] ?? 0) as num;
              final ts = data['createdAt'] as Timestamp?;
              final date = ts != null
                  ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year}'
                  : 'Just now';
              final time = ts != null
                  ? '${ts.toDate().hour.toString().padLeft(2, '0')}:${ts.toDate().minute.toString().padLeft(2, '0')}'
                  : '';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.9),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Icon badge
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0A500).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.volunteer_activism_rounded,
                              color: Color(0xFFF0A500),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Title & date
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '$date${time.isNotEmpty ? ' · $time' : ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Amount + badge
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${amount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF24963F),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF24963F,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Success',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
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
              );
            }),

            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  Widget _buildTopDonators() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.leaderboard_rounded, color: Color(0xFFF0A500)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Top 5 Donators',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFB71C1C),
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AllDonatorsScreen()),
                );
              },
              child: const Text(
                'View All >',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFF0A500),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: _topDonatorsStream,
          builder: (context, snapshot) {
            // Only show spinner on the very first load (no data yet).
            // On subsequent live updates, snapshot.hasData stays true
            // so we skip the spinner entirely — no flicker.
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 80,
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF24963F)),
                ),
              );
            }
            if (snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('No public donators found yet.'));
            }

            final docs = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['isPublic'] == true;
            }).toList();

            docs.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              // Sort by totalDonated, fallback to punyaScore
              final aAmt =
                  (aData['totalDonated'] ?? aData['punyaScore'] ?? 0) as num;
              final bAmt =
                  (bData['totalDonated'] ?? bData['punyaScore'] ?? 0) as num;
              return bAmt.compareTo(aAmt);
            });

            final top5 = docs.take(5).toList();

            if (top5.isEmpty) {
              return const Center(child: Text('No public donators found yet.'));
            }

            return Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: top5.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final data = top5[index].data() as Map<String, dynamic>;
                  final name = data['name'] ?? 'Anonymous';
                  final score =
                      (data['totalDonated'] ?? data['punyaScore'] ?? 0) as num;
                  final photoUrl =
                      data['photoUrl'] ??
                      data['photoURL']; // Handle both common variants

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFFFF3D6),
                      backgroundImage: photoUrl != null
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl == null
                          ? const Icon(Icons.person_rounded,
                              color: Color(0xFFF0A500))
                          : null,
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF5C4033),
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '₹${score.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Color(0xFF24963F),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEventCard(Map<String, dynamic> data) {
    final imageUrl = data['imageUrl'] as String? ?? '';
    final title = data['title'] ?? data['name'] ?? 'Unnamed Event';
    final creator = data['creatorName'] ?? 'Unknown';
    final targetAmount = (data['targetAmount'] ?? 0) as num;
    final location = data['location'] as String? ?? '';

    return Container(
      width: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade400.withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(4, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image — same as TempleCard
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: imageUrl.startsWith('http')
                      ? Image.network(
                          imageUrl,
                          height: 125,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                height: 125,
                                color: Colors.grey.shade200,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.event_rounded,
                                  color: Colors.grey,
                                  size: 40,
                                ),
                              ),
                        )
                      : Container(
                          height: 125,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF24963F), Color(0xFF1E7A33)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.event_rounded,
                            color: Colors.white38,
                            size: 48,
                          ),
                        ),
                ),
                // Content — same as TempleCard
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'By: $creator',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        // Green pill — same style as TempleCard location pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFE8F5E9,
                            ).withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white, width: 0.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.monetization_on_rounded,
                                      size: 16,
                                      color: Color(0xFF24963F),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        location.isNotEmpty
                                            ? location
                                            : '₹${targetAmount.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF24963F),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Donate',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(String query) {
    final lq = query.toLowerCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Search Results',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('events')
              .where('status', isEqualTo: 'approved')
              .snapshots(),
          builder: (context, eventSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('organizations')
                  .where('status', isEqualTo: 'approved')
                  .snapshots(),
              builder: (context, orgSnap) {
                final List<Widget> results = [];

                // Match events
                if (eventSnap.hasData) {
                  for (var doc in eventSnap.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final title = (data['title'] ?? data['name'] ?? '')
                        .toString()
                        .toLowerCase();
                    final desc = (data['description'] ?? '')
                        .toString()
                        .toLowerCase();
                    final category = (data['category'] ?? '')
                        .toString()
                        .toLowerCase();
                    if (title.contains(lq) ||
                        desc.contains(lq) ||
                        category.contains(lq)) {
                      results.add(
                        _buildSearchResultTile(
                          title: data['title'] ?? data['name'] ?? 'Untitled',
                          subtitle: data['category'] ?? 'Event',
                          icon: Icons.event_rounded,
                          badgeLabel: 'Event',
                          badgeColor: const Color(0xFF24963F),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EventDetailScreen(
                                eventId: doc.id,
                                eventData: data,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                  }
                }

                // Match organizations
                if (orgSnap.hasData) {
                  for (var doc in orgSnap.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final desc = (data['description'] ?? '')
                        .toString()
                        .toLowerCase();
                    final category = (data['category'] ?? '')
                        .toString()
                        .toLowerCase();
                    if (name.contains(lq) ||
                        desc.contains(lq) ||
                        category.contains(lq)) {
                      final org = Organization.fromFirestore(doc);
                      results.add(
                        _buildSearchResultTile(
                          title: org.name,
                          subtitle: org.category,
                          icon: Icons.location_city_rounded,
                          badgeLabel: 'Place',
                          badgeColor: const Color(0xFFE89344),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrganizationDetailScreen(
                                organization: org,
                                currentPosition: _currentPosition,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                  }
                }

                if (results.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    alignment: Alignment.center,
                    child: Text(
                      'No results for "$query"',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  );
                }
                return Column(children: results);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildSearchResultTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required String badgeLabel,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: badgeColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: badgeColor,
                        ),
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? 'Glen Macx';
    final photoUrl = user?.photoURL;

    return PopScope(
      canPop: false,
      child: Scaffold(
        resizeToAvoidBottomInset:
            false, // Prevents keyboard from pushing up floating bottom nav
        extendBody: true,
        // Give the Scaffold a very soft, ambient gradient background
        // to make the glassy cards actually look visibly frosted!
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF6F8FD), Color(0xFFE9F0E6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // Main content tabs
              IndexedStack(
                index: _currentNavIndex,
                children: [
                  // 0: Home Page Content
                  SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(
                      bottom: 120,
                    ), // Padding for the bottom nav
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Top Bar
                            Row(
                              children: [
                                StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(user?.uid ?? '')
                                      .snapshots(),
                                  builder: (context, userSnap) {
                                    final userData =
                                        (userSnap.hasData &&
                                            userSnap.data!.exists)
                                        ? (userSnap.data!.data()
                                              as Map<String, dynamic>)
                                        : <String, dynamic>{};

                                    // Profile completion ring (same logic as ProfilePage)
                                    int filled = 0;
                                    const total = 7;
                                    if (((userData['firstName'] as String? ??
                                                '')
                                            .trim()
                                            .isNotEmpty ||
                                        (user?.displayName ?? '')
                                            .trim()
                                            .isNotEmpty)) {
                                      filled++;
                                    }
                                    if ((userData['lastName'] as String? ?? '')
                                        .trim()
                                        .isNotEmpty) {
                                      filled++;
                                    }
                                    if ((user?.email ??
                                            userData['email'] as String? ??
                                            '')
                                        .trim()
                                        .isNotEmpty) {
                                      filled++;
                                    }
                                    if ((userData['location'] as String? ?? '')
                                        .trim()
                                        .isNotEmpty) {
                                      filled++;
                                    }
                                    if ((userData['aadharNumber'] as String? ??
                                            '')
                                        .trim()
                                        .isNotEmpty) {
                                      filled++;
                                    }
                                    if ((userData['panNumber'] as String? ?? '')
                                        .trim()
                                        .isNotEmpty) {
                                      filled++;
                                    }
                                    if ((user?.photoURL ?? '').isNotEmpty) {
                                      filled++;
                                    }
                                    final double progress = filled / total;
                                    final bool isComplete = progress >= 1.0;
                                    final Color ringColor = isComplete
                                        ? const Color(0xFF24963F)
                                        : const Color(0xFFB71C1C);

                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const ProfilePage(),
                                          ),
                                        );
                                      },
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          SizedBox(
                                            width: 56,
                                            height: 56,
                                            child: CircularProgressIndicator(
                                              value: progress,
                                              backgroundColor: ringColor
                                                  .withValues(alpha: 0.2),
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    ringColor,
                                                  ),
                                              strokeWidth: 3.5,
                                            ),
                                          ),
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundColor:
                                                Colors.grey.shade200,
                                            backgroundImage: photoUrl != null
                                                ? NetworkImage(photoUrl)
                                                : null,
                                            child: photoUrl == null
                                                ? const Icon(
                                                    Icons.account_circle,
                                                    color: Colors.black87,
                                                    size: 48,
                                                  )
                                                : null,
                                          ),
                                          if (isComplete)
                                            Positioned(
                                              bottom: 0,
                                              right: 0,
                                              child: Container(
                                                width: 16,
                                                height: 16,
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF24963F,
                                                  ),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.check_rounded,
                                                  size: 10,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF5C4033),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.location_on_outlined,
                                            size: 14,
                                            color: Colors.black54,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              _currentLocation,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade700,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Notifications
                                IconButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const NotificationsScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.notifications_none_rounded,
                                    color: Color(0xFF5C4033),
                                    size: 28,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // 2. Search Bar (Glassy)
                            Container(
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 10,
                                    sigmaY: 10,
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.6,
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.6,
                                        ),
                                        width: 1.5,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.search_rounded,
                                          color: Colors.black87,
                                        ), // Black search icon
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Stack(
                                            alignment: Alignment.centerLeft,
                                            children: [
                                              if (_searchController
                                                  .text
                                                  .isEmpty)
                                                AnimatedSwitcher(
                                                  duration: const Duration(
                                                    milliseconds: 300,
                                                  ),
                                                  transitionBuilder:
                                                      (
                                                        Widget child,
                                                        Animation<double>
                                                        animation,
                                                      ) {
                                                        return FadeTransition(
                                                          opacity: animation,
                                                          child: child,
                                                        );
                                                      },
                                                  child: Container(
                                                    key: ValueKey<int>(
                                                      _searchHighlightIndex,
                                                    ),
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: Text(
                                                      'Search "${_searchHighlights[_searchHighlightIndex]}"',
                                                      style: const TextStyle(
                                                        color: Colors.black54,
                                                        fontSize: 15,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                              TextField(
                                                controller: _searchController,
                                                onChanged: (val) =>
                                                    setState(() {}),
                                                onSubmitted: (val) {
                                                  FocusScope.of(
                                                    context,
                                                  ).unfocus();
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Searching for: $val',
                                                      ),
                                                    ),
                                                  );
                                                },
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  color: Colors.black87,
                                                ),
                                                decoration:
                                                    const InputDecoration(
                                                      border: InputBorder.none,
                                                      isDense: true,
                                                      contentPadding:
                                                          EdgeInsets.zero,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            _isListening
                                                ? Icons.mic
                                                : Icons.mic_none_rounded,
                                            color: _isListening
                                                ? Colors.red
                                                : Colors.black87,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: _listenToSpeech,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),
                            // 3. Punya Score Card
                            _buildCarouselCard(_buildPunyaScoreContent()),

                            const SizedBox(height: 32),

                            // 4. Categories Row — horizontally scrollable
                            SizedBox(
                              height: 110,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                children: [
                                  _CategoryItem(
                                    title: 'Religious Places',
                                    imageAsset:
                                        'assets/home/religious_places.png',
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CategoryAllScreen(
                                          title: 'Temples',
                                          category: 'Temple',
                                          currentPosition: _currentPosition,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _CategoryItem(
                                    title: 'Gaushala',
                                    imageAsset: 'assets/home/Gaushala.png',
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CategoryAllScreen(
                                          title: 'Gaushalas',
                                          category: 'Gaushala',
                                          currentPosition: _currentPosition,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _CategoryItem(
                                    title: 'Charity',
                                    imageAsset: 'assets/home/Charity.png',
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CategoryAllScreen(
                                          title: 'Charities',
                                          category: 'Charity',
                                          currentPosition: _currentPosition,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _CategoryItem(
                                    title: 'KanyaDaan',
                                    imageAsset: 'assets/home/KanyaDaan.png',
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CategoryAllScreen(
                                          title: 'KanyaDaan',
                                          category: 'Kanyadaan',
                                          currentPosition: _currentPosition,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _CategoryItem(
                                    title: 'YogDaan',
                                    imageAsset: 'assets/home/YogDaan.png',
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CategoryAllScreen(
                                          title: 'Yogdaan',
                                          category: 'Yogdaan',
                                          currentPosition: _currentPosition,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                              ),
                            ),

                            const SizedBox(height: 48), // Spacing before lists
                            // Sections
                            // Search Results Overlay — shown when search is active
                            if (_searchController.text.trim().isNotEmpty)
                              _buildSearchResults(_searchController.text.trim())
                            else ...[
                              _buildTopDonators(),

                              const SizedBox(height: 32),
                              _buildRecentDonations(),

                              _buildDynamicListSection(
                                'Nearby Temples',
                                'Temple',
                                _orgTempleStream,
                                _eventTempleStream,
                              ),
                              const SizedBox(height: 36),
                              _buildDynamicListSection(
                                'Nearby Gaushalas',
                                'Gaushala',
                                _orgGaushalaStream,
                                _eventGaushalaStream,
                              ),
                              const SizedBox(height: 36),
                              _buildDynamicListSection(
                                'Nearby Charities',
                                'Charity',
                                _orgCharityStream,
                                _eventCharityStream,
                              ),
                              const SizedBox(height: 36),
                              _buildDynamicListSection(
                                'KanyaDaan',
                                'Kanyadaan',
                                _orgKanyadaanStream,
                                _eventKanyadaanStream,
                              ),
                              const SizedBox(height: 36),
                              _buildDynamicListSection(
                                'Yogdaan',
                                'Yogdaan',
                                _orgYogdaanStream,
                                _eventYogdaanStream,
                              ),
                            ], // end of else spread
                          ],
                        ),
                      ),
                    ),
                  ), // End of SingleChildScrollView
                  const DoneeYourEventsScreen(showCreateButton: true),
                  const Center(child: Text('Scan Screen - Coming Soon')),
                  const TransactionsScreen(),
                ],
              ),

              // Floating Crimson Bottom Navigation Bar
              Positioned(
                bottom: 24,
                left: 20,
                right: 20,
                child: Container(
                  height: 68,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB71C1C),
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFB71C1C).withValues(alpha: 0.45),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _BottomNavItem(
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home_rounded,
                        label: 'Home',
                        isActive: _currentNavIndex == 0,
                        onTap: () => setState(() => _currentNavIndex = 0),
                      ),
                      _BottomNavItem(
                        icon: Icons.calendar_today_outlined,
                        activeIcon: Icons.calendar_today_rounded,
                        label: 'Event',
                        isActive: _currentNavIndex == 1,
                        onTap: () => setState(() => _currentNavIndex = 1),
                      ),
                      _BottomNavItem(
                        icon: Icons.qr_code_scanner_rounded,
                        activeIcon: Icons.qr_code_scanner_rounded,
                        label: 'Scan',
                        isActive: false,
                        onTap: () async {
                          final scannedValue = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ScannerScreen(),
                            ),
                          );

                          if (scannedValue != null &&
                              scannedValue.contains(
                                'punyadaan-e0972.web.app/org/',
                              )) {
                            final orgId = scannedValue
                                .split('punyadaan-e0972.web.app/org/')
                                .last;

                            // Show loading while fetching
                            if (context.mounted) {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF24963F),
                                  ),
                                ),
                              );
                            }

                            try {
                              final doc = await FirebaseFirestore.instance
                                  .collection('organizations')
                                  .doc(orgId)
                                  .get();

                              if (context.mounted) {
                                Navigator.pop(context); // hide loading

                                if (doc.exists) {
                                  final org = Organization.fromFirestore(doc);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => OrganizationDetailScreen(
                                        organization: org,
                                        currentPosition: _currentPosition,
                                      ),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Organization not found.'),
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              if (context.mounted) {
                                Navigator.pop(context); // hide loading
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Error loading organization: $e',
                                    ),
                                  ),
                                );
                              }
                            }
                          }
                        },
                      ),
                      _BottomNavItem(
                        icon: Icons.receipt_long_outlined,
                        activeIcon: Icons.receipt_long_rounded,
                        label: 'Transactions',
                        isActive: _currentNavIndex == 3,
                        onTap: () => setState(() => _currentNavIndex = 3),
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

  Widget _buildDynamicListSection(
    String title,
    String category,
    Stream<QuerySnapshot> orgStream,
    Stream<QuerySnapshot> eventStream,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFB71C1C),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CategoryAllScreen(
                      title: title,
                      category: category,
                      currentPosition: _currentPosition,
                    ),
                  ),
                );
              },
              child: const Text(
                'View All >',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFF0A500),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height:
              270, // Generous height to fit image (125) and text and huge shadow safely
          child: StreamBuilder<QuerySnapshot>(
            stream: orgStream,
            builder: (context, orgSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: eventStream,
                builder: (context, eventSnapshot) {
                  if (orgSnapshot.connectionState == ConnectionState.waiting &&
                      eventSnapshot.connectionState ==
                          ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: Colors.amber.shade700,
                      ),
                    );
                  }

                  final List<dynamic> combinedItems = [];
                  if (orgSnapshot.hasData) {
                    combinedItems.addAll(
                      orgSnapshot.data!.docs.map(
                        (d) => {'type': 'org', 'doc': d},
                      ),
                    );
                  }
                  if (eventSnapshot.hasData) {
                    combinedItems.addAll(
                      eventSnapshot.data!.docs.map(
                        (d) => {'type': 'event', 'doc': d},
                      ),
                    );
                  }

                  if (combinedItems.isEmpty) {
                    return Center(
                      child: Text(
                        'No $title or events found.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    itemCount: combinedItems.length,
                    itemBuilder: (context, index) {
                      final item = combinedItems[index];
                      if (item['type'] == 'org') {
                        final doc = item['doc'] as QueryDocumentSnapshot;
                        final org = Organization.fromFirestore(doc);
                        String distanceText = 'N/A';
                        if (_currentPosition != null &&
                            org.locationPin != null) {
                          double distanceInMeters = Geolocator.distanceBetween(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                            org.locationPin!.latitude,
                            org.locationPin!.longitude,
                          );
                          distanceText =
                              '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
                        }
                        return Padding(
                          padding: const EdgeInsets.only(right: 20, bottom: 20),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OrganizationDetailScreen(
                                    organization: org,
                                    currentPosition: _currentPosition,
                                  ),
                                ),
                              );
                            },
                            child: _TempleCard(
                              title: org.name,
                              distance: distanceText,
                              location: org.locationName,
                              imageUrl: org.imageUrl,
                            ),
                          ),
                        );
                      } else {
                        final doc2 = item['doc'] as QueryDocumentSnapshot;
                        final data = doc2.data() as Map<String, dynamic>;
                        final eventId = doc2.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 20, bottom: 20),
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
                            child: _buildEventCard(data),
                          ),
                        );
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryItem extends StatelessWidget {
  const _CategoryItem({
    required this.title,
    required this.imageAsset,
    this.onTap,
  });

  final String title;
  final String imageAsset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool isYogdaan = title == 'YogDaan';
    return SizedBox(
      width: isYogdaan ? 100 : 90,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: isYogdaan ? 72 : 64,
              width: isYogdaan ? 72 : 64,
              child: Image.asset(
                imageAsset,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const Center(
                      child: Icon(Icons.category, color: Colors.grey),
                    ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  color: Color(0xFF5C4033),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TempleCard extends StatelessWidget {
  const _TempleCard({
    required this.title,
    required this.distance,
    required this.location,
    required this.imageUrl,
  });

  final String title;
  final String distance;
  final String location;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240, // Wider for text safety and shadow padding
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade400.withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(4, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7), // Glassy fill
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Fixed height image container protects flexible Column layout underneath
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: imageUrl.startsWith('http')
                      ? Image.network(
                          imageUrl,
                          height: 125,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                height: 125,
                                color: Colors.grey.shade200,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.image,
                                  color: Colors.grey,
                                ),
                              ),
                        )
                      : Image.asset(
                          imageUrl,
                          height: 125,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                height: 125,
                                color: Colors.grey.shade200,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.image,
                                  color: Colors.grey,
                                ),
                              ),
                        ),
                ),
                // Content bottom half expands beautifully into rest of constraint (250-125 = 125px)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              distance,
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        // Light green track pill matching user design images identically
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFE8F5E9,
                            ).withValues(alpha: 0.8), // subtle glassy child
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white, width: 0.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_rounded,
                                      size: 16,
                                      color: Colors.black87,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      // Inner Expander to clamp very long location titles
                                      child: Text(
                                        location,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF5C4033),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF24963F),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Donate',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 18 : 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          // Active pill: Primary Gold; inactive: transparent
          color: isActive ? const Color(0xFFF0A500) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFFF0A500).withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : icon,
                color: Colors.white,
                size: 26),
            AnimatedSize(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              alignment: Alignment.centerLeft,
              child: isActive
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
