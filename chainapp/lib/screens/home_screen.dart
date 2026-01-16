import 'dart:async'; // StreamSubscription ve Timer için
import 'dart:ui'; // Glassmorphism efektleri için
import 'dart:convert'; // JSON işlemleri için
import 'dart:math'; // Konfeti yönü için
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http; // API için
import 'package:confetti/confetti.dart'; // 🔥 KÜTÜPHANE

// Servisler ve Modeller
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../models/chain_model.dart';
import '../models/chain_log_model.dart';

// Diğer Sayfalar
import 'chain_hub_screen.dart';
import 'profile_screen.dart';
import 'timer_screen.dart';
import 'chain_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final String chainId;
  final String chainName;

  const HomeScreen({
    super.key,
    required this.chainId,
    required this.chainName,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _firestoreService = FirestoreService();
  final _auth = FirebaseAuth.instance;

  TimeOfDay? _notificationTime;
  StreamSubscription? _nudgeSubscription;

  // Motivasyon Sözü Değişkeni
  Future<Map<String, String>>? _dailyQuote;

  // Konfeti Kontrolcüsü
  late ConfettiController _confettiController;

  // 🔥 GERİ SAYIM SAYACI İÇİN DEĞİŞKENLER
  Timer? _dayTimer;
  String _timeLeftString = "";

  @override
  void initState() {
    super.initState();
    // Konfeti süresi (2 saniye patlasın)
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));

    _listenForNudges();
    // Sözü çek
    _dailyQuote = _fetchDailyQuote();

    // 🔥 SAYACI BAŞLAT
    _startDayCountdown();
  }

  @override
  void dispose() {
    _nudgeSubscription?.cancel();
    _confettiController.dispose();
    _dayTimer?.cancel(); // 🔥 Timer'ı durdur
    super.dispose();
  }

  // 🔥 GÜN SONUNA NE KADAR KALDI HESAPLAYAN FONKSİYON
  void _startDayCountdown() {
    // İlk hesaplama hemen yapılsın
    _updateTimeLeft();

    // Her dakikada bir güncelle
    _dayTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateTimeLeft();
    });
  }

  void _updateTimeLeft() {
    final now = DateTime.now();
    // Bugünün sonu (23:59:59)
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final difference = endOfDay.difference(now);

    if (difference.isNegative) {
      setState(() {
        _timeLeftString = "Day Ended";
      });
    } else {
      setState(() {
        _timeLeftString =
            "${difference.inHours}h ${difference.inMinutes % 60}m left";
      });
    }
  }

  // --- API'DEN SÖZ ÇEKME ---
  Future<Map<String, String>> _fetchDailyQuote() async {
    try {
      final response =
          await http.get(Uri.parse('https://zenquotes.io/api/random'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return {
          'quote': data[0]['q'],
          'author': data[0]['a'],
        };
      } else {
        return {
          'quote': "Keep moving forward, one link at a time.",
          'author': "Chain App"
        };
      }
    } catch (e) {
      return {
        'quote': "Believe you can and you're halfway there.",
        'author': "T. Roosevelt"
      };
    }
  }

  // --- DÜRTME DİNLEYİCİSİ ---
  void _listenForNudges() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _nudgeSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          final msg = data['message'] ?? "Someone nudged you!";

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.waving_hand, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(child: Text("Someone nudged you: \"$msg\"")),
                  ],
                ),
                backgroundColor: const Color(0xFF6C5ECF),
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: "OK",
                  textColor: Colors.white,
                  onPressed: () {
                    change.doc.reference.update({'isRead': true});
                  },
                ),
              ),
            );
            change.doc.reference.update({'isRead': true});
          }
        }
      }
    });
  }

  // --- ANA AKSİYON (CHECK-IN / REPAIR) ---
  Future<void> _handleAction(ChainModel chain) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // --- DURUM 1: TAMİR (REPAIR) ---
    if (chain.status == 'broken') {
      try {
        final batch = FirebaseFirestore.instance.batch();
        DocumentReference chainRef =
            FirebaseFirestore.instance.collection('chains').doc(chain.id);
        batch.set(
            chainRef,
            {'status': 'active', 'streakCount': 0, 'membersCompletedToday': []},
            SetOptions(merge: true));
        DocumentReference userRef =
            FirebaseFirestore.instance.collection('users').doc(userId);
        batch.set(userRef, {'xp': FieldValue.increment(-50)},
            SetOptions(merge: true));
        await batch.commit();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Chain Repaired! 50 XP used. 🛠️"),
            backgroundColor: Colors.blue));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Repair Error: $e"), backgroundColor: Colors.red));
      }
      return;
    }

    // --- DURUM 2: CHECK-IN ---
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F3D78),
        title: const Text("Daily Goal?", style: TextStyle(color: Colors.white)),
        content: const Text("Mark today as completed?",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Confirm")),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final newLog = ChainLog(
            userId: userId, logDate: DateTime.now(), note: "Manual Check-in");
        await _firestoreService.performCheckIn(chain.id, userId, newLog);

        // Konfeti Patlat
        _confettiController.play();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  // --- BİLDİRİM SAATİ ---
  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _notificationTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFA68FFF),
              onPrimary: Colors.white,
              surface: Color(0xFF142A52),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _notificationTime = picked);
      try {
        await NotificationService().scheduleDailyNotification(
          id: widget.chainId.hashCode,
          title: "Don't Break the Chain! 🔥",
          body: "Time to complete your ${widget.chainName} goal!",
          time: picked,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Reminder set for ${picked.format(context)} daily ⏰"),
            backgroundColor: Colors.green.shade600));
      } catch (e) {
        print("PickTime Error: $e");
      }
    }
  }

  // --- DÜRTME PENCERESİ ---
  void _showNudgeDialog(
      String memberId, String userName, String chainId, String chainName) {
    final TextEditingController messageController = TextEditingController();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F3D78),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.waving_hand, color: Colors.orangeAccent),
            const SizedBox(width: 10),
            Expanded(
                child: Text("Nudge $userName",
                    style: const TextStyle(color: Colors.white, fontSize: 18))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Send them a quick motivational message! 🚀",
                style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 15),
            TextField(
              controller: messageController,
              style: const TextStyle(color: Colors.white),
              maxLength: 50,
              decoration: InputDecoration(
                hintText: "E.g.: You can do it!",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                counterStyle: const TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel",
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA68FFF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(ctx);
              String msg = messageController.text.trim();
              if (msg.isEmpty) msg = "Waiting for you! 👋";
              try {
                await FirestoreService().sendNudge(
                    currentUserId!, memberId, chainId, chainName, msg);
              } catch (e) {
                print("Nudge error: $e");
              }
            },
            child: const Text("SEND", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- ZİNCİR HALKASI ---
  Widget _buildChainNode(
      String dayNum, bool isDone, bool isToday, bool isLast) {
    final Color doneColor = Colors.greenAccent;
    final Color activeColor = Colors.white;
    final Color inactiveColor = Colors.white24;

    return SizedBox(
      width: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!isLast)
            Positioned(
              right: 0,
              left: 30,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: isDone ? doneColor.withOpacity(0.5) : inactiveColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: isDone
                  ? Colors.green.withOpacity(0.8)
                  : (isToday
                      ? Colors.white.withOpacity(0.1)
                      : Colors.transparent),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDone
                    ? doneColor
                    : (isToday ? activeColor : inactiveColor),
                width: (isToday || isDone) ? 2 : 1,
              ),
              boxShadow: isDone
                  ? [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      )
                    ]
                  : [],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isDone
                    ? Icon(Icons.check,
                        key: const ValueKey("check"),
                        color: activeColor,
                        size: 26)
                    : Text(
                        dayNum,
                        key: const ValueKey("text"),
                        style: TextStyle(
                          color: isToday ? activeColor : Colors.white54,
                          fontSize: 16,
                          fontWeight:
                              isToday ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- ÜYE AVATARI ---
  Widget _buildMemberAvatar(
      String memberId, bool isCompleted, String chainId, String chainName) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isMe = memberId == currentUserId;

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('users').doc(memberId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final avatarSeed = data?['avatarSeed'] ?? 'user';
        final userName = data?['name'] ?? 'User';

        return Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: isCompleted
                                ? Colors.greenAccent
                                : Colors.redAccent.withOpacity(0.6),
                            width: 2.5)),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.black26,
                      backgroundImage: NetworkImage(
                          "https://api.dicebear.com/9.x/adventurer/png?seed=$avatarSeed&backgroundColor=b6e3f4"),
                    ),
                  ),
                  if (!isCompleted && !isMe)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () {
                          _showNudgeDialog(
                              memberId, userName, chainId, chainName);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(blurRadius: 4, color: Colors.black26)
                              ]),
                          child: const Icon(Icons.waving_hand,
                              size: 14, color: Colors.orange),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- ALT MENÜ ---
  Widget _buildBottomBar(BuildContext context, ChainModel chain) {
    return Container(
      height: 85,
      decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          border:
              Border(top: BorderSide(color: Colors.white.withOpacity(0.1)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TimerScreen(),
                ),
              );
            },
            icon: const Icon(Icons.timer, color: Colors.white70, size: 30),
          ),
          GestureDetector(
            onTap: () {
              if (context.findAncestorWidgetOfExactType<HomeScreen>() != null) {
                return;
              }
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => HomeScreen(
                    chainId: widget.chainId,
                    chainName: widget.chainName,
                  ),
                ),
                (route) => false,
              );
            },
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF1F3D78),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 10,
                  )
                ],
                border: Border.all(color: Colors.white24, width: 2),
              ),
              child:
                  const Icon(Icons.home_filled, color: Colors.white, size: 32),
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(
                    selectedChainId: widget.chainId,
                    selectedChainName: widget.chainName,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.person, color: Colors.white70, size: 32),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chains')
          .doc(widget.chainId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              backgroundColor: Color(0xFF0A0E25),
              body: Center(
                  child: CircularProgressIndicator(color: Colors.white)));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
              backgroundColor: const Color(0xFF0A0E25),
              body: Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    const Text("Chain data not found.",
                        style: TextStyle(color: Colors.white)),
                    const SizedBox(height: 20),
                    ElevatedButton(
                        onPressed: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ChainHubScreen())),
                        child: const Text("Go to Hub"))
                  ])));
        }

        final chainData = snapshot.data!.data() as Map<String, dynamic>;
        final chain = ChainModel.fromMap(snapshot.data!.id, chainData);
        final bool isCompletedToday =
            chain.membersCompletedToday.contains(currentUserId);
        final bool isBroken = chain.status == 'broken';

        return SafeArea(
          child: Scaffold(
            backgroundColor: const Color(0xFF0A0E25),
            bottomNavigationBar: _buildBottomBar(context, chain),
            extendBodyBehindAppBar: true,
            appBar: AppBar(
                title: Text(chain.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white)),
                centerTitle: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ChainHubScreen()),
                        )),
                actions: [
                  IconButton(
                      icon: Icon(Icons.notifications_active,
                          color: _notificationTime != null
                              ? Colors.amber
                              : Colors.white54),
                      onPressed: _pickTime)
                ]),
            body: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                    decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [
                  Color(0xFF0A0E25),
                  Color(0xFF1F3D78),
                  Color(0xFF6C5ECF)
                ], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
                SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 60,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: 7,
                            itemBuilder: (context, index) {
                              final nodeDate = DateTime.now()
                                  .subtract(Duration(days: 3 - index));
                              final nodeDateStr =
                                  DateFormat('yyyy-MM-dd').format(nodeDate);

                              final dayNum = DateFormat('d').format(nodeDate);
                              final isToday = index == 3;
                              final isFuture = index > 3;

                              bool isDone = false;

                              if (isToday) {
                                isDone = chain.membersCompletedToday
                                    .contains(currentUserId);
                              } else if (!isFuture) {
                                isDone = (chain.completedDates ?? [])
                                    .contains(nodeDateStr);
                              }

                              return _buildChainNode(
                                  dayNum, isDone, isToday, index == 6);
                            },
                          ),
                        ),
                        const SizedBox(height: 30),

                        // 🔥 ANA AKSİYON KARTI VE SAYACI
                        GestureDetector(
                          onTap: (isBroken || !isCompletedToday)
                              ? () => _handleAction(chain)
                              : null,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color:
                                              Colors.white.withOpacity(0.1))),
                                  child: Row(children: [
                                    Container(
                                        width: 55,
                                        height: 55,
                                        decoration: BoxDecoration(
                                            color: isBroken
                                                ? Colors.red
                                                : (isCompletedToday
                                                    ? Colors.green
                                                    : Colors.transparent),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: isBroken
                                                    ? Colors.redAccent
                                                    : (isCompletedToday
                                                        ? Colors.green
                                                        : Colors.white54),
                                                width: 2)),
                                        child: Center(
                                            child: isBroken
                                                ? const Icon(Icons.build,
                                                    color: Colors.white)
                                                : (isCompletedToday
                                                    ? const Icon(Icons.check,
                                                        color:
                                                            Color(0xFF0A0E25),
                                                        size: 30)
                                                    : null))),
                                    const SizedBox(width: 16),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Text(
                                              isBroken
                                                  ? "Chain Broken!"
                                                  : "Daily Goal",
                                              style: TextStyle(
                                                  color: isBroken
                                                      ? Colors.redAccent
                                                      : Colors.white54,
                                                  fontSize: 12)),

                                          // 🔥 BURADA GÖREV ADINI VE GERİ SAYIMI GÖSTERİYORUZ
                                          Text(
                                              isBroken
                                                  ? "Tap to Repair (50 XP)"
                                                  : (isCompletedToday
                                                      ? "Completed! 🎉"
                                                      : (chain.purpose
                                                              .isNotEmpty
                                                          ? chain.purpose
                                                          : chain.name)),
                                              style: TextStyle(
                                                  color: isCompletedToday
                                                      ? Colors.white
                                                          .withOpacity(0.5)
                                                      : Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  decoration: isCompletedToday
                                                      ? TextDecoration
                                                          .lineThrough
                                                      : null),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),

                                          // 🔥 SAYAÇ EKLENDİ (SADECE GÖREV BİTMEDİYSE VE KIRIK DEĞİLSE GÖRÜNÜR)
                                          if (!isCompletedToday && !isBroken)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 4.0),
                                              child: Text(
                                                "⏳ $_timeLeftString", // Geri sayım
                                                style: const TextStyle(
                                                    color: Color(
                                                        0xFFA68FFF), // Tema rengi
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            )
                                        ]))
                                  ])),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),
                        const Text("Team Status",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        SizedBox(
                            height: 90,
                            child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: chain.members.length,
                                itemBuilder: (context, index) {
                                  final memberId = chain.members[index];
                                  final isMemCompleted = chain
                                      .membersCompletedToday
                                      .contains(memberId);
                                  return _buildMemberAvatar(memberId,
                                      isMemCompleted, chain.id, chain.name);
                                })),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      ChainDetailScreen(chain: chain))),
                          child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white10)),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text("About this Chain",
                                              style: TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold)),
                                          Icon(Icons.arrow_forward_ios,
                                              color:
                                                  Colors.white.withOpacity(0.3),
                                              size: 14)
                                        ]),
                                    const SizedBox(height: 8),
                                    Text(
                                        chain.description.isNotEmpty
                                            ? chain.description
                                            : "No description provided.",
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            height: 1.4),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis)
                                  ])),
                        ),
                        const SizedBox(height: 30),

                        // MOTIVATION QUOTE CARD
                        FutureBuilder<Map<String, String>>(
                          future: _dailyQuote,
                          builder: (context, quoteSnapshot) {
                            if (quoteSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.white30));
                            }
                            final quote = quoteSnapshot.data?['quote'] ??
                                "Focus on your goals.";
                            final author =
                                quoteSnapshot.data?['author'] ?? "Unknown";

                            return ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFA68FFF)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: const Color(0xFFA68FFF)
                                            .withOpacity(0.2)),
                                  ),
                                  child: Column(
                                    children: [
                                      const Icon(Icons.format_quote,
                                          color: Color(0xFFA68FFF), size: 30),
                                      const SizedBox(height: 10),
                                      Text(
                                        quote,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontStyle: FontStyle.italic,
                                            fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(height: 12),
                                      Text("- $author",
                                          style: const TextStyle(
                                              color: Color(0xFFA68FFF),
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),

                // 🔥 CONFETTI WIDGET ON TOP OF EVERYTHING
                Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirection: pi / 2, // Downwards
                    maxBlastForce: 5,
                    minBlastForce: 2,
                    emissionFrequency: 0.05,
                    numberOfParticles: 20,
                    gravity: 0.2,
                    colors: const [
                      Colors.green,
                      Colors.blue,
                      Colors.pink,
                      Colors.orange,
                      Colors.purple
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
