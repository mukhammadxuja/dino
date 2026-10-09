# 🚦 Ustuvorlik va Hodisalar Mantiqi (Priority & Event Logic)

## 📌 Kirish
Bir vaqtning o‘zida musiqa ijro etilayotgan, taymer ishlab turgan va birdan foydalanuvchi klaviaturada ovozni o‘zgartirsa yoki Ob-havo shortcutini bossa, Dino qanday qaror qabul qilishi kerak? 

Buning uchun **Priority Queue (Ustuvorlik Navbati)** va **Interrupt & Resume (To‘xtatib turish va qaytish)** tizimi joriy qilinadi.

---

## 🏗️ 1. Ustuvorlik Ierarxiyasi (4 ta Daraja)

```
┌────────────────────────────────────────────────────────┐
│  P1: SYSTEM TOAST (Vaqtinchalik Tizim Hodisalari)      │  <- Eng yuqori (1.5 - 3.0s)
├────────────────────────────────────────────────────────┤
│  P2: USER ON-DEMAND (Shortcut / Qasddan Chaqirilgan)   │  <- O'rta (5.0s yoki Sticky)
├────────────────────────────────────────────────────────┤
│  P3: ACTIVE BACKGROUND (Doimiy Jonli Jarayonlar)       │  <- Doimiy (Musiqa, Taymer)
├────────────────────────────────────────────────────────┤
│  P4: IDLE STATE (Tinch / Standart Holat)               │  <- Bo'sh kapsula
└────────────────────────────────────────────────────────┘
```

### P1 — System Toast (Eng yuqori ustuvorlik)
Bu hodisalar barcha narsani (hatto ochiq turgan ob-havo yoki musiqani) bir zumga to‘xtatib (interrupt), o‘zini ko‘rsatadi va vaqti tugagach avvalgi holatga qaytaradi:
* **Volume HUD:** Ovoz o‘zgarganda (1.5 soniya).
* **Brightness HUD:** Yorqinlik o‘zgarganda (1.5 soniya).
* **Charger / Battery Alert:** Zaryadga ulanganda / uzilganda yoki batareya < 20% bo‘lganda (3.0 soniya).
* **Shelf Drag Hover:** Fayl notch ustiga keltirilganda (fayl qo‘yib yuborilguncha).
* **Caps Lock / Mute:** Caps lock bosilganda (1.2 soniya).

### P2 — User On-Demand (Foydalanuvchi Chaqiruvi)
Foydalanuvchi klaviatura yorlig‘i (Shortcut) orqali maxsus chaqirgan featlar:
* **Weather Shortcut (`Option + W`):** `☀️ 25°` chiqadi.
* **Calendar Shortcut (`Option + C`):** Navbatdagi uchrashuv chiqadi.
* **Qaytish qoidasi:** Foydalanuvchi uni ko‘rib bo‘lgach (sozlamalardagi `Auto-dismiss Timeout`, masalan 5s), tizim avtomatik P3 dagi musiqaga qaytadi.

### P3 — Active Background Activities (Doimiy Jarayonlar)
Fonda uzoq davom etuvchi faoliyatlar:
* **Musiqa ijrosi** (Apple Music, Spotify, YouTube Music).
* **Pomodoro / Taymer** oraliqlari.
* **Katta hajmdagi fayl yuklanishi** (Downloads).

---

## 👥 2. Dual-Activity (Bir vaqtda ikkita P3 jarayon bo‘lsa)

Agar bir vaqtning o‘zida ham **Musiqa** ketyapti, ham **Pomodoro** sanayotgan bo‘lsa nima bo‘ladi?

### A. Split Island Strategiyasi (Tavsiya etiladi)
Notch ikkita qismga bo‘linadi:
* **Chap qanot:** `|||` Aylanuvchi musiqa visualizer'i yoki kichik albom rasmi.
* **O‘ng qanot:** `🍅 24:50` Pomodoro hisoblagichi.
* Foydalanuvchi qaysi tomonga bossa, aynan o‘sha tomon to‘liq karta ko‘rinishida kengayadi (Expanded).

### B. Swipe / Click to Swap (Almashtirish)
Foydalanuvchi o‘ng qanot ustida trekpadda sursa (swipe) yoki bitta bossa, ikkinchi aktiv jarayonga almashadi.

---

## ⏱️ 3. State Transition Matrix (Holatlar O‘tish Jadvali)

| Joriy Holat | Yangi Hodisa | Tizim Reaksiyasi | Qaytish Sharti |
|---|---|---|---|
| **Musiqa (P3)** | Volume tugmasi bosildi | 1.5s ga Volume HUD ga aylanadi | 1.5s o‘tgach silliq yana Musiqaga qaytadi |
| **Musiqa (P3)** | `Option + W` (Ob-havo) bosildi | Orolcha `☀️ 25°` ga o‘tadi | 5s o‘tgach (yoki Esc bosilganda) Musiqaga qaytadi |
| **Ob-havo (P2)** | Zaryadlovchi ulandi | 3s ga Battery animatsiyasi chiqadi | 3s dan keyin Ob-havoga, keyin Musiqaga qaytadi |
| **Bo‘sh (P4)** | Fayl sudrab kelindi | Shelf darchasi ochiladi | Fayl tashlangach yana Bo‘sh holatga qaytadi |
