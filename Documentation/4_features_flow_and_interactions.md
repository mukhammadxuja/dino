# 🕹️ Har bir Feat Bo‘yicha To‘liq Interaksiyalar va Oqim (Features Flow)

## 📌 Kirish
Ushbu hujjatda Dino ilovasidagi har bir funksiya (feat) bo‘yicha:
1. Qanday holatda ishga tushishi,
2. Foydalanuvchi nima qilganda (User Action) nima ro‘y berishi,
3. Closed (yopiq/ixcham) va Open (ochiq/kengaygan) holatlardagi ko‘rinishi batafsil tushuntiriladi.

---

## 🎵 1. Music & Media Player

### A. Ishga tushish:
Foydalanuvchi Apple Music, Spotify, YouTube Music yoki Safari’da media boshlaganda avtomatik faollashadi.

### B. Closed Holati (Ixcham orolcha):
* **Chap qanot:** Ovoz to‘lqinlari (Metal Audio Visualizer) yoki Play/Pause holati.
* **O‘ng qanot:** Qo‘shiqning kichik albom muqovasi (Cover Art).
* **Hover:** Sichqoncha yaqinlashtirilganda kichik preview (Track nomi va san'atkor).

### C. Open Holati (Kengaygan karta — Standard 360x145pt):
* Katta albom rasmi, qo‘shiq nomi, ijrochi.
* Interaktiv elementlar: Play/Pause, Oldinga/Orqaga, Slider (Seek bar), Ovoz slayderi, Sevimlilar (Like/Heart), Repeat/Shuffle.

---

## 🍅 2. Pomodoro Timer (Fokus Taymeri)

### A. Ishga tushish:
* Shortcut orqali (`Option + P`), menyudan yoki taymer boshlanganda.

### B. Closed Holati:
* **Chap qanot:** 🍅 Qizil pomidor ikonkasi (fokus vaqtida) yoki ☕️ kofe finjoni (dam olish vaqtida).
* **O‘ng qanot:** Qolgan vaqt sanog‘i (`24:50`).

### C. Open Holati (Compact 280x90pt):
* Katta raqamli taymer va progress doirasi.
* Tugmalar: Pause/Resume, Skip (Keyingi oraliqqa o‘tish), Reset (Qayta boshlash).
* Vaqt tugaganda: Yumshoq haptic va audio signal yangraydi.

---

## ☀️ 3. Weather (Ob-havo)

### A. Ishga tushish:
* Foydalanuvchi `Option + W` shortcutini bosganda yoki menyudan tanlaganda.

### B. Closed Holati (Ixcham Pill):
* **Chap:** Quyosh/Bulut ikonkasi (`☀️` / `🌧️`).
* **O‘ng:** Joriy harorat (`25°`).

### C. Open Holati (Standard 360x145pt):
* **Yuqori qism:** Shahar nomi (masalan "Toshkent"), joriy harorat, ob-havo holati ("Quyoshli"), Kunlik Max/Min harorat.
* **Pastki qism:** 5 kunlik ob-havo prognozi (Kun nomi, ikonkasi va kutilayotgan harorat).

---

## 🔊 4. Inline HUD (Volume & Brightness)

### A. Ishga tushish:
* Hech qanday shortcutsiz, foydalanuvchi klaviaturadagi ovoz yoki yorqinlik tugmalarini bosganda.

### B. Ko‘rinishi:
* Notch darhol mini-kapsulaga aylanadi.
* **Chap:** Ovoz (`􀊤`) yoki Yorqinlik (`􀆮`) ikonkasi.
* **O‘ng:** Silliq to‘lib boruvchi progress bar va foiz ko‘rsatkichi.
* **Davomiyligi:** Tugma bosilishi to‘xtagach 1.5 soniya ko‘rinib turadi va silliq orqaga qaytadi.

---

## 📂 5. Shelf / Drop Zone (Drag & Drop)

### A. Ishga tushish:
* Foydalanuvchi Finder yoki boshqa ilovadan fayl, rasm yoki havolani sichqoncha bilan ushlab, Notch tomon sudrab kelganda.

### B. Ko‘rinishi (Large 440x210pt):
* Notch kengayib, qulay fayllar tokchasiga (Shelf) aylanadi.
* Fayl tokchaga tashlanadi (`Drop`) va foydalanuvchi boshqa dasturga o‘tib, undan bemalol nusxa olib ishlatishi mumkin.
* Qo‘shimcha tugmalar: Tezkor AirDrop, tozalash, ulashish.

---

## 🔋 6. Battery & Charger Status

### A. Ishga tushish:
* MagSafe / Type-C zaryadlovchi ulanganda, uzilganda yoki quvvat 20% / 10% dan tushib ketganda.

### B. Ko‘rinishi (Compact Toast):
* **Chap:** Yashil zaryadlanish animatsiyasi (`⚡️`).
* **O‘ng:** Quvvat foizi (`88%`) va to‘liq quvvatlanguncha qolgan vaqt.
* 3.0 soniyadan keyin avtomatik yopiladi.
