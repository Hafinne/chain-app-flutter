import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/chain_model.dart';
import '../models/chain_log_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- 1. KULLANICI OLUŞTURMA ---
  Future<void> createUser(UserModel user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  // --- 2. KULLANICI TAKİBİ (STREAM) ---
  Stream<UserModel> streamUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return UserModel(uid: 'error', email: '', name: 'Error');
      }
      return UserModel.fromFirestore(snapshot);
    });
  }

  // --- 3. ZİNCİR KONTROL ROBOTU (AÇILIŞTA ÇALIŞIR - DÜZELTİLDİ) ---
  // 🔥 BU FONKSİYON ARTIK GÜNÜ SIFIRLAR VE ZİNCİRİ KIRAR
  Future<void> checkChainsOnAppStart(String userId) async {
    try {
      final snapshot = await _db
          .collection('chains')
          .where('members', arrayContains: userId)
          .get();

      for (var doc in snapshot.docs) {
        final chainId = doc.id;
        final data = doc.data();

        // Son aktivite tarihini al (PerformCheckIn'de kaydediyoruz)
        Timestamp? lastActivityTs = data['lastActivityDate'];

        // Eğer tarih yoksa (yeni zincirse) veya işlem yapılmamışsa geç
        if (lastActivityTs == null) continue;

        DateTime lastActivity = lastActivityTs.toDate();
        DateTime now = DateTime.now();

        // Tarihleri sadece Yıl/Ay/Gün olarak karşılaştır (Saat farkını yoksay)
        DateTime lastDate =
            DateTime(lastActivity.year, lastActivity.month, lastActivity.day);
        DateTime today = DateTime(now.year, now.month, now.day);

        // Fark kaç gün?
        int difference = today.difference(lastDate).inDays;

        // SENARYO A: YENİ GÜN BAŞLAMIŞ (Fark >= 1)
        if (difference >= 1) {
          // Listeyi temizle ki buton tekrar aktif olsun
          await _db.collection('chains').doc(chainId).update({
            'membersCompletedToday': [],
          });
        }

        // SENARYO B: ZİNCİR KIRILMIŞ (Fark > 1, yani dün yapılmamış)
        if (difference > 1 && data['status'] == 'active') {
          await _db.collection('chains').doc(chainId).update({
            'status': 'broken',
            'streakCount': 0, // Seriyi sıfırla
            'brokenAt': FieldValue.serverTimestamp(),
          });
          print("☠️ Zincir Kırıldı: $chainId (Fark: $difference gün)");
        }
      }
    } catch (e) {
      print("Zincir kontrol hatası: $e");
    }
  }

  // --- 4. CHECK-IN YAPMA (GÜNCELLENDİ) ---
  Future<void> performCheckIn(
      String chainId, String userId, ChainLog logData) async {
    final chainRef = _db.collection('chains').doc(chainId);
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return _db.runTransaction((transaction) async {
      DocumentSnapshot chainSnap = await transaction.get(chainRef);
      Map<String, dynamic> data = chainSnap.data() as Map<String, dynamic>;

      List members = data['members'] ?? [];
      List completedToday = data['membersCompletedToday'] ?? [];

      if (completedToday.contains(userId)) return;

      // 1. Kullanıcıyı bugünkü listeye ekle
      // 🔥 ÖNEMLİ: 'lastActivityDate' alanını güncelliyoruz ki Robot çalışsın
      transaction.update(chainRef, {
        'membersCompletedToday': FieldValue.arrayUnion([userId]),
        'lastActivityDate': FieldValue.serverTimestamp(), // Tarihi kaydet
        'status': 'active', // Kırıksa düzelt
      });

      // 2. EĞER HERKES TAMAMLADIYSA: Streak artır
      if (completedToday.length + 1 == members.length) {
        transaction.update(chainRef, {
          'streakCount': FieldValue.increment(1),
          'completedDates': FieldValue.arrayUnion([todayStr]),
        });
      }

      // Log kaydı oluştur
      transaction.set(chainRef.collection('logs').doc(), logData.toMap());

      // 3. XP Uygula
      await _applyXPChange(userId, 10);
    });
  }

  // --- YARDIMCI: XP EKLE/ÇIKAR VE ROZET GÜNCELLE ---
  Future<void> _applyXPChange(String userId, int amount) async {
    final userRef = _db.collection('users').doc(userId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      if (!snapshot.exists) return;

      int currentXp = snapshot.data()?['xp'] ?? 0;
      int newXp = currentXp + amount;
      if (newXp < 0) newXp = 0;

      // Rozet Hesapla (Senin mantığın korundu)
      String newBadge = "Rookie";
      if (newXp >= 10000)
        newBadge = "Legend";
      else if (newXp >= 5000)
        newBadge = "Master";
      else if (newXp >= 2500)
        newBadge = "Elite";
      else if (newXp >= 1000)
        newBadge = "Warrior";
      else if (newXp >= 500) newBadge = "Scout";

      transaction.update(userRef, {
        'xp': newXp,
        'badge': newBadge,
      });
    });
  }

  // --- DİĞER METOTLAR (AYNEN KORUNDU) ---
  Stream<List<ChainModel>> streamUserChains(String userId) {
    return _db
        .collection('chains')
        .where('members', arrayContains: userId)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => ChainModel.fromMap(d.id, d.data())).toList());
  }

  // ZİNCİRDEN ÜYE ATMA
  Future<void> removeMember(String chainId, String memberId) async {
    await _db.collection('chains').doc(chainId).update({
      'members': FieldValue.arrayRemove([memberId])
    });
  }

  // 5. DÜRTME (NUDGE) SİSTEMİ
  Future<void> sendNudge(String senderId, String receiverId, String chainId,
      String chainName, String message) async {
    try {
      await _db
          .collection('users')
          .doc(receiverId)
          .collection('notifications')
          .add({
        'type': 'nudge',
        'fromUserId': senderId,
        'chainId': chainId,
        'chainName': chainName,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
      print("Dürtme gönderildi! 🔔");
    } catch (e) {
      print("Dürtme hatası: $e");
      rethrow;
    }
  }

  // 6. SIRALAMA HESAPLAMA (RANK)
  Future<int> getUserRank(int myXp) async {
    try {
      AggregateQuerySnapshot query = await _db
          .collection('users')
          .where('xp', isGreaterThan: myXp)
          .count()
          .get();

      int count = query.count ?? 0;
      return count + 1;
    } catch (e) {
      print("Sıralama hatası: $e");
      return 0;
    }
  }
}
