import 'dart:ui'; // Font özellikleri için
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/Timer_service.dart';

class TimerScreen extends StatelessWidget {
  const TimerScreen({super.key});

  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final timerProvider = context.watch<TimerProvider>();

    // İlerleme yüzdesi hesapla
    int totalSeconds = timerProvider.selectedMinutes * 60;
    double progress =
        totalSeconds == 0 ? 0 : timerProvider.remainingSeconds / totalSeconds;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Focus Mode",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. ARKA PLAN (Gradient)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0A0E25),
                  Color(0xFF1F3D78),
                  Color(0xFF6C5ECF),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // 2. İÇERİK
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 🔥 SANA LAZIM OLAN KISIM BURASI:
                // Alarm çalıyorsa EKRANI DEĞİŞTİRİYORUZ.
                if (timerProvider.isAlarmActive) ...[
                  // --- ALARM MODU ---
                  const Icon(Icons.alarm_on,
                      size: 100, color: Colors.redAccent),
                  const SizedBox(height: 20),
                  const Text("TIME IS UP!",
                      style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 10),
                  const Text("Don't break the chain, you're amazing!",
                      style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 50),

                  // KOCAMAN SUSTUR BUTONU
                  GestureDetector(
                    onTap: () => timerProvider.stopAlarm(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 50, vertical: 20),
                      decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.red.withOpacity(0.6),
                                blurRadius: 30,
                                spreadRadius: 5)
                          ]),
                      child: const Text("STOP ALARM",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                    ),
                  )
                ] else ...[
                  // --- NORMAL SAYAÇ MODU (Modern Halka) ---
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Arka iz (Gri halka)
                      SizedBox(
                        width: 280,
                        height: 280,
                        child: CircularProgressIndicator(
                          value: 1.0,
                          color: Colors.white.withOpacity(0.1),
                          strokeWidth: 20,
                        ),
                      ),
                      // Ön doluluk (Renkli halka)
                      SizedBox(
                        width: 280,
                        height: 280,
                        child: CircularProgressIndicator(
                          value: progress,
                          color: const Color(0xFFA68FFF), // Mor Tema
                          backgroundColor: Colors.transparent,
                          strokeWidth: 20,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      // Ortadaki Yazı
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                              timerProvider.isRunning
                                  ? "Focusing..."
                                  : "Are you ready?",
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 16,
                                  letterSpacing: 1.5)),
                          const SizedBox(height: 10),
                          Text(
                            _formatTime(timerProvider.remainingSeconds),
                            style: const TextStyle(
                              fontSize: 60,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 60),

                  // SÜRE AYARLAMA (+ ve -)
                  if (!timerProvider.isRunning)
                    Container(
                      margin: const EdgeInsets.only(bottom: 40),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildTimeControl(
                              icon: Icons.remove,
                              onTap: () => timerProvider.setMinutes(
                                  timerProvider.selectedMinutes - 1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text("${timerProvider.selectedMinutes} Dk",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600)),
                          ),
                          _buildTimeControl(
                              icon: Icons.add,
                              onTap: () => timerProvider.setMinutes(
                                  timerProvider.selectedMinutes + 1)),
                        ],
                      ),
                    ),

                  // BAŞLAT / DURAKLAT BUTONU
                  GestureDetector(
                    onTap: () => timerProvider.toggleTimer(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 60, vertical: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: timerProvider.isRunning
                              ? [Colors.orangeAccent, Colors.deepOrange]
                              : [
                                  const Color(0xFFA68FFF),
                                  const Color(0xFF6C5ECF)
                                ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: timerProvider.isRunning
                                ? Colors.orange.withOpacity(0.4)
                                : const Color(0xFFA68FFF).withOpacity(0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Text(
                        timerProvider.isRunning ? "PAUSE" : "START",
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 1.2),
                      ),
                    ),
                  ),
                ], // else bloğu sonu
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Küçük buton widget'ı (+ ve - için)
  Widget _buildTimeControl(
      {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}
