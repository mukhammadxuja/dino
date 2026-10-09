# 🦖 Dino (sobiq boringNotch) — Asosiy Loyiha Hujjati

## 📌 Loyiha Haqida
**Dino** — bu macOS uchun ishlab chiqilgan, zamonaviy **Dynamic Island va Notch kengaytmasi** hisoblanadi. U MacBook’dagi apparat (hardware) notch yoki tashqi monitorlardagi bo‘sh Menu Bar maydonini interaktiv, jonli va nihoyatda foydali ma'lumotlar markaziga aylantiradi.

Ilova ilgari ochiq kodli *boringNotch* loyihasidan fork qilingan bo‘lib, hozirda to‘liq qayta rebrending qilinmoqda, arxitekturasi modullashtirilmoqda va har bir funksiya mustaqil (Dynamic Island uslubida) ishlaydigan darajaga keltirilmoqda.

---

## 🧭 Loyihadagi Mavjud va Rejalashtirilgan Funksiyalar (Featlar Holati)

| # | Funksiya (Feat) | Tavsifi | Hozirgi Holati | Kelgusi Reja |
|---|---|---|---|---|
| 1 | **🎵 Music Player** | Apple Music, Spotify, YouTube Music integratsiyasi, visualizer va artwork | ✅ To‘liq ishlaydi | `ContentView`dan alohida `MusicSlotView`ga ajratish, visualizer timerini optimallash |
| 2 | **🍅 Pomodoro Timer** | Ish va dam olish oraliqlarini hisoblovchi fokus taymer | ✅ To‘liq ishlaydi | Chap qanotda ikonka, o‘ngda `24:50` qilib ixchamlashtirish |
| 3 | **🔊 Inline HUD** | Ovoz balandligi (Volume) va yorqinlik (Brightness) mini-indikatori | ✅ To‘liq ishlaydi | 1.5s Toast prioriteti tizimiga ulash |
| 4 | **🔋 Battery Status** | Quvvat foizi va zaryadlovchi ulangandagi animatsiya | ✅ To‘liq ishlaydi | Faqat zaryadga ulanganda yoki <20% bo‘lganda avto-chiqish |
| 5 | **📂 Shelf (Drop Zone)** | Fayllarni notch ustiga sudrab kelib vaqtincha saqlash va ulashish | ✅ Ishlaydi | Drag paytida boshqa featlarni vaqtincha bosib turish mantiqi |
| 6 | **☀️ Weather (Ob-havo)** | Mini-pill harorat (`☀️ 25°`) va 5 kunlik batafsil karta | 🟡 Chala / Yangilanmoqda | Shortcut bilan chaqirish va Open kartasini yangilash |
| 7 | **📅 Calendar & Events**| Yaqinlashib kelayotgan uchrashuvlarni ko‘rsatish | 🟡 Qorishiq | Faol uchrashuvga 15 daqiqa qolganda avtomatik chiqish |
| 8 | **📷 Webcam Mirror** | Uchrashuvlar oldidan tezkor ko‘zgu | ✅ Ishlaydi | O‘lchamlarini standartlashtirish |
| 9 | **📥 Download Progress** | Fayllar yuklanishi progress bari | 🟡 Boshlang‘ich | Safari/brauzer yuklamalari bilan to‘liq integratsiya |
| 10| **🎮 Antigravity & Dino**| Mini o‘yin va interaktiv animatsiyalar | 🟡 Bog‘liqlik kuchli | Asosiy koddan mustaqil qilib ajratish |
| 11| **⚙️ Priority Coordinator**| Qaysi feat qachon chiqishini boshqaruvchi markaziy miya | ❌ Yangi yaratiladi | Barcha to‘qnashuvlarni (conflicts) hal qiluvchi asosiy poydevor |

---

## ⚙️ Settings (Sozlamalar) -> General Bo‘limi Qanday Bo‘lishi Kerak?

Foydalanuvchi ilovani o‘ziga moslab sozlashi uchun **Settings -> General** bo‘limida quyidagi eng muhim parametrlar joylashishi lozim:

### 1. Ekran va Form Factor (Display & Shape)
* **Display Selection:** `[ Built-in Screen Only | External Display Only | Both Screens ]`
* **Form Factor (Tashqi monitor uchun):**
  * `Floating Island` (Suzuvchi ixcham kapsula — tavsiya etiladi).
  * `Fake Notch` (Tepaga yopishgan sun'iy qora notch).
* **Notch Height Mode (Built-in uchun):**
  * `Match Real Hardware Notch` (Kamera ramkasiga 1:1 yopishish).
  * `Match Menu Bar Height`.

### 2. Xulq-atvor va Vaqtlar (Behavior & Timeouts)
* **Shortcut Auto-dismiss Timeout:** Foydalanuvchi shortcut orqali (masalan Ob-havoni) chaqirganda, qancha vaqtdan keyin orqa fondagi musiqaga/standart holatga qaytsin?
  * Variantlar: `[ 3 soniya | 5 soniya (Standart) | 10 soniya | Doimiy turish (Manual Esc) ]`
* **Toast Duration:** Ovoz va yorqinlik o‘zgarganda HUD qancha tursin?
  * Variantlar: `[ 1.0s | 1.5s (Standart) | 2.5s ]`
* **Dual-Activity Strategy:** Bir vaqtning o‘zida ham musiqa, ham taymer faol bo‘lsa:
  * Variantlar: `[ Split Island (Ikki tomonga bo'lish) | Dominant Feat (Faqat bittasini ko'rsatish) ]`

### 3. Tizim va Ishga Tushish (System & Startup)
* **Launch at Login:** Mac yoqilganda avtomatik ishga tushish (Toggle).
* **Show Menu Bar Icon:** Menyular satrida Dino ikonkasi ko‘rinishi (Toggle).
* **Haptic & Sound Feedback:** Amallar bajarilganda ovozli va vibro signallar berish (Toggle).
* **Check for Updates:** Avtomatik yangilanishlarni tekshirish (Sparkle).
