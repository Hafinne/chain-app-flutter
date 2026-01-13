import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart'; // Senin istediğin paket

class TimerProvider extends ChangeNotifier {
  Timer? _timer;
  int _selectedMinutes = 25;
  int _remainingSeconds = 25 * 60;
  bool _isRunning = false;

  // 🔥 YENİ: Alarmın çaldığını takip eden değişken
  bool _isAlarmActive = false;

  final AudioPlayer _audioPlayer = AudioPlayer();

  TimerProvider() {
    debugPrint("✅ [TIMER SERVICE]: Provider yüklendi.");
  }

  // Getter'lar
  int get selectedMinutes => _selectedMinutes;
  int get remainingSeconds => _remainingSeconds;
  bool get isRunning => _isRunning;
  bool get isAlarmActive => _isAlarmActive; // UI bunu dinleyecek

  void setMinutes(int minutes) {
    if (!_isRunning && !_isAlarmActive && minutes > 0) {
      _selectedMinutes = minutes;
      _remainingSeconds = minutes * 60;
      notifyListeners();
    }
  }

  void toggleTimer() {
    // Eğer alarm çalıyorsa butona basınca alarmı durdur
    if (_isAlarmActive) {
      stopAlarm();
    } else if (_isRunning) {
      _stopTimer();
    } else {
      _startTimer();
    }
  }

  void _startTimer() {
    _isRunning = true;
    _isAlarmActive = false; // Yeni başlarken alarm kapalı olsun
    notifyListeners();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        _onFinished();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _isRunning = false;
    notifyListeners();
  }

  void _onFinished() async {
    _timer?.cancel();
    _isRunning = false;
    _remainingSeconds = _selectedMinutes * 60; // Süreyi başa sar

    // 🔥 Alarm durumunu aktif et
    _isAlarmActive = true;
    notifyListeners();

    try {
      // Sesi döngüye al (Sen durdurana kadar çalsın)
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('alarm.mp3'));
    } catch (e) {
      debugPrint("❌ Ses Hatası: $e");
    }
  }

  // 🔥 ALARMI DURDURMA FONKSİYONU
  void stopAlarm() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint("❌ Durdurma hatası: $e");
    }
    _isAlarmActive = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}
