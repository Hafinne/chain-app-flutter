# chain-app-flutter
Chain is a productivity app that reimagines the "Break the Chain" method for groups. Teams of 3-5 people set a daily goal. Everyone must complete that day's task for the chain to progress. If a member skips, the chain resets. This social accountability mechanic aims to increase your team's motivation and cohesion.
# 🔗 Chain App

**Chain**, bireysel alışkanlık takibini **sosyal sorumluluk** ile birleştiren bir mobil uygulamadır. 3-5 kişilik gruplar halinde tek bir hedefe kilitlenirsiniz. Kural basit: **Biri zinciri kırarsa, herkesin zinciri sıfırlanır.**

## 📱 Uygulama İçi Görseller

| Ana Sayfa & Zincirler | Detay & Davet Kodu | Odak Modu (Timer) | Profil & Rozetler |
|:---:|:---:|:---:|:---:|
| <img src="screenshots/home.png" width="180"/> | <img src="screenshots/detail.png" width="180"/> | <img src="screenshots/focus.png" width="180"/> | <img src="screenshots/profile.png" width="180"/> |

---
## ✨ Öne Çıkan Özellikler

### 🤝 Sosyal Özellikler
* Kolektif Sorumluluk:Grup üyelerinden sadece biri bile günlük "Check-in" yapmazsa, tüm grubun serisi (Streak) yanar.
* Dürtme (Nudge) Sistemi: Görevini yapmayı unutan arkadaşına tek tıkla **anlık bildirim** göndererek onu uyarabilirsin.
* Kolay Davet: Her grup için özel üretilen kısa kodlar (Örn: `C47A3F`) ile arkadaşlarınızı saniyeler içinde ekibe dahil edebilirsiniz.

###  Üretkenlik Araçları
* Odak Modu (Focus Timer): Entegre Pomodoro sayacı ile (25 dk) uygulamadan çıkmadan hedefinize odaklanabilirsiniz.
* Kişiselleştirilebilir Alarm: "Local Notification" teknolojisi ile, internetiniz olmasa bile **kendi belirlediğiniz saatte** hatırlatıcı bildirim alırsınız.

### 🎮 Oyunlaştırma (Gamification)
* XP ve Seviye Sistemi: Zinciri sürdürdükçe XP kazanır, Seviye 1'den yukarı tırmanır ve global sıralamada yükselirsiniz.
* Zincir Tamiri: Kritik durumlarda, biriktirdiğiniz puanları (XP) harcayarak kırılan zinciri onarabilir ve seriyi kurtarabilirsiniz.
* Rozetler: Düzenli alışkanlıklarınız karşılığında özel başarı rozetleri kazanırsınız.

---

## 🛠️ Teknik Mimari (Backend)

Uygulama, **Google Firebase Serverless** mimarisi üzerinde, yüksek performans ve veri güvenliği odaklı inşa edilmiştir.

* Lazy Evaluation (Tembel Kontrol):** Sunucuyu sürekli çalıştırmak yerine, zincir durumu kontrolü kullanıcı giriş yaptığı an (On-Demand) hesaplanır. Bu sayede sunucu maliyeti minimize edilmiştir.
* *Atomic Transactions: XP harcama ve zincir onarma işlemleri atomik bloklar halinde yapılır. Aynı anda binlerce işlem olsa bile veri kaybı veya karışıklık (Race Condition) yaşanmaz.
* Firestore Security Rules: Veri güvenliği doğrudan veritabanı katmanında sağlanmıştır; kullanıcılar sadece kendi gruplarına erişebilir.

---

## 👥 Geliştirici Ekibi
Selim Elibüyük** - Frontend Lead & UI/UX
Hanife Korkmaz** - Backend Lead & Architecture
Muhammet Tokuç** - PM & QA

---
*Abdullah Gül Üniversitesi (AGÜ) Bilgisayar Mühendisliği Projesi.*
