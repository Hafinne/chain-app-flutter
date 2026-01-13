import 'dart:ui'; // Glassmorphism efektleri için
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Modeller ve Servisler
import '../models/user_model.dart';
import '../services/firestore_service.dart';

// Diğer Sayfalar
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'timer_screen.dart';
// import 'chain_hub_screen.dart'; // Gerekirse ekle

class ProfileScreen extends StatelessWidget {
  // 🔥 Hangi zincirden gelindiğini hatırlamak için
  final String selectedChainId;
  final String selectedChainName;

  const ProfileScreen({
    super.key,
    required this.selectedChainId,
    required this.selectedChainName,
  });

  // BADGE TANIMLARI (İngilizce)
  static const List<Map<String, dynamic>> allBadges = [
    {
      'id': 'Newbie',
      'name': 'Newbie',
      'icon': '🥚',
      'desc': 'You joined the chain world!',
      'howTo': 'Earned by registering an account.',
      'xp': 10
    },
    {
      'id': '3Day',
      'name': '3-Day Spark',
      'icon': '✨',
      'desc': 'Discipline is starting to ignite.',
      'howTo': 'Complete a 3-day streak without breaking.',
      'xp': 20
    },
    {
      'id': 'Lvl5',
      'name': 'Novice Chain',
      'icon': '⛓️',
      'desc': 'You are no longer a rookie.',
      'howTo': 'Reach Level 5 to unlock this badge.',
      'xp': 50
    },
    {
      'id': '7Day',
      'name': 'Weekly Warrior',
      'icon': '🛡️',
      'desc': 'A full week! Nobody can stop you.',
      'howTo': 'Complete a 7-day streak without breaking.',
      'xp': 100
    },
    {
      'id': 'Lvl10',
      'name': 'Consistent Link',
      'icon': '🔗',
      'desc': 'Mastering the art of habits.',
      'howTo': 'Reach Level 10 to unlock this badge.',
      'xp': 150
    },
    {
      'id': 'Lvl25',
      'name': 'Elite 25',
      'icon': '🔟',
      'desc': 'You are approaching legend status.',
      'howTo': 'Reach Level 25 to unlock this badge.',
      'xp': 300
    },
    {
      'id': 'Legend',
      'name': 'The Legend',
      'icon': '🔥',
      'desc': 'Peak discipline! You are an inspiration.',
      'howTo': 'Reach Level 50 to unlock this badge.',
      'xp': 1000
    },
  ];

  // --- ÇIKIŞ YAPMA ---
  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // --- BADGE DETAY PENCERESİ ---
  void _showBadgeDetail(
      BuildContext context, Map<String, dynamic> badge, bool isEarned) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E1B4B).withOpacity(0.9),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(badge['icon'], style: const TextStyle(fontSize: 60)),
              const SizedBox(height: 16),
              Text(badge['name'],
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(badge['desc'],
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
              const SizedBox(height: 8),
              Text("Requirement: ${badge['howTo']}",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                      fontStyle: FontStyle.italic)),
              const SizedBox(height: 24),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isEarned
                      ? Colors.green.withOpacity(0.2)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isEarned ? Colors.greenAccent : Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isEarned ? Icons.check_circle : Icons.lock,
                        color: isEarned ? Colors.greenAccent : Colors.white38,
                        size: 18),
                    const SizedBox(width: 8),
                    Text(
                      isEarned ? "Earned (+${badge['xp']} XP)" : "Locked",
                      style: TextStyle(
                          color: isEarned ? Colors.greenAccent : Colors.white38,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- BADGE GALERİSİ ---
  void _showBadgeGallery(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E1B4B).withOpacity(0.95),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Text("Badge Collection",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: allBadges.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                childAspectRatio: 0.75,
              ),
              itemBuilder: (context, index) {
                final b = allBadges[index];
                bool isEarned = user.earnedBadges.contains(b['id']);
                return GestureDetector(
                  onTap: () => _showBadgeDetail(context, b, isEarned),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: isEarned ? 1.0 : 0.2,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  shape: BoxShape.circle),
                              child: Text(b['icon'],
                                  style: const TextStyle(fontSize: 28)),
                            ),
                          ),
                          if (!isEarned)
                            Icon(Icons.lock,
                                color: Colors.white.withOpacity(0.4), size: 20),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(b['name'],
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: TextStyle(
                              color: isEarned ? Colors.white : Colors.white24,
                              fontSize: 10,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // --- BOTTOM BAR (NAVIGATION) ---
  Widget _buildBottomBar(BuildContext context) {
    return Container(
      height: 85,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 1. SOL: TIMER Butonu
          IconButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  // 🔥 DÜZELTİLEN KISIM: Parametreler silindi
                  builder: (_) => const TimerScreen(),
                ),
              );
            },
            icon: const Icon(Icons.timer, color: Colors.white70, size: 30),
          ),

          // 2. ORTA: HOME Butonu
          GestureDetector(
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => HomeScreen(
                    chainId: selectedChainId,
                    chainName: selectedChainName,
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

          // 3. SAĞ: PROFILE Butonu (Aktif Sayfa)
          IconButton(
            onPressed: () {
              // Zaten Profile sayfasındayız, işlem yok.
            },
            icon: const Icon(Icons.person, color: Color(0xFFA68FFF), size: 32),
          ),
        ],
      ),
    );
  }

  // --- UI YARDIMCILARI ---
  Widget _buildGlassContainer(
      {required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildGlassStatCard(String title, String value) {
    return _buildGlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(title,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6), fontSize: 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Scaffold(body: Center(child: Text("Error")));

    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        extendBodyBehindAppBar: true,
        bottomNavigationBar: _buildBottomBar(context),
        appBar: AppBar(
          title: const Text("Profile",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
              icon: const Icon(Icons.settings, color: Colors.white70),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()))),
          actions: [
            IconButton(
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                onPressed: () => _logout(context))
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Arka Plan Gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0A0E25),
                    Color(0xFF1E1B4B),
                    Color(0xFF312E81)
                  ],
                ),
              ),
            ),

            // İçerik
            SafeArea(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFFA68FFF)));
                  if (!snapshot.hasData || !snapshot.data!.exists)
                    return const Center(
                        child: Text("User data not found",
                            style: TextStyle(color: Colors.white)));

                  UserModel user = UserModel.fromFirestore(snapshot.data!);
                  double progress = (user.xp - user.xpStartCurrentLevel) /
                      (user.xpRequiredForNextLevel - user.xpStartCurrentLevel);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Avatar
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: const Color(0xFFA68FFF)
                                        .withOpacity(0.5),
                                    width: 4),
                                image: DecorationImage(
                                  image: NetworkImage(
                                      "https://api.dicebear.com/9.x/adventurer/png?seed=${user.avatarSeed}&backgroundColor=b6e3f4"),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            FloatingActionButton.small(
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          EditProfileScreen(user: user))),
                              backgroundColor: const Color(0xFFA68FFF),
                              child:
                                  const Icon(Icons.edit, color: Colors.white),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        Text(user.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),

                        // Badges Row
                        GestureDetector(
                          onTap: () => _showBadgeGallery(context, user),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFFA68FFF).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: const Color(0xFFA68FFF)
                                          .withOpacity(0.5)),
                                ),
                                child: const Text("Badges 🎖️",
                                    style: TextStyle(
                                        color: Color(0xFFA68FFF),
                                        fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 40,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: user.earnedBadges.length,
                                    itemBuilder: (context, index) {
                                      final badgeId = user.earnedBadges[index];
                                      final bData = allBadges.firstWhere(
                                          (e) => e['id'] == badgeId,
                                          orElse: () => allBadges[0]);
                                      return GestureDetector(
                                        onTap: () => _showBadgeDetail(
                                            context, bData, true),
                                        child: Container(
                                          margin:
                                              const EdgeInsets.only(right: 8),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withOpacity(0.08),
                                              shape: BoxShape.circle),
                                          child: Text(bData['icon'],
                                              style: const TextStyle(
                                                  fontSize: 16)),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Level Progress
                        _buildGlassContainer(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Level ${user.level}",
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                  Text(
                                      "${user.xp} / ${user.xpRequiredForNextLevel} XP",
                                      style: TextStyle(
                                          color:
                                              Colors.white.withOpacity(0.6))),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: progress.clamp(0.0, 1.0),
                                  backgroundColor:
                                      Colors.white.withOpacity(0.1),
                                  color: const Color(0xFFA68FFF),
                                  minHeight: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                  "${user.xpRequiredForNextLevel - user.xp} XP to next level",
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 12)),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Stats Grid
                        Row(
                          children: [
                            Expanded(
                                child: _buildGlassStatCard(
                                    "Total XP", "${user.xp} ✨")),
                            const SizedBox(width: 15),
                            Expanded(
                              child: FutureBuilder<int>(
                                future: FirestoreService().getUserRank(user.xp),
                                builder: (context, rSnap) =>
                                    _buildGlassStatCard(
                                        "Chain Rank",
                                        rSnap.hasData
                                            ? "#${rSnap.data} 🏆"
                                            : "..."),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
