# 🦖 Rebranding: boringNotch'dan Dino'ga O‘tish

## 📌 Kirish
Loyihani mustaqil, o‘ziga xos va esda qolarli mahsulotga aylantirish uchun eski **"boringNotch"** brendidan to‘liq **"Dino"** brendiga o‘tish amalga oshiriladi.

---

## 🎨 1. Brending Konsepsiyasi

* **Nomi:** **Dino** (Dinamik, chaqqon va interaktiv macOS hamrohi).
* **Slogan:** *Your Mac's notch, evolved.*
* **Asosiy Qadriyatlar:**
  * **Minimalizm:** Ekranda ortiqcha joy egallamaydi, faqat kerak bo‘lganda chiqadi.
  * **Tezlik:** Protsessorni yuklamaydi, 60/120Hz silliq animatsiyalar.
  * **Maxfiylik (Privacy):** 100% lokal, hech qanday ma'lumot to‘plamaydi.

---

## 🛠️ 2. Texnik Rebranding Ro‘yxati (Checklist)

| Qism | Eski Nomi | Yangi Nomi |
|---|---|---|
| **App Nomi** | `boringNotch` | **`Dino`** |
| **Bundle Identifier** | `com.harsh.boringNotch` | **`com.dino.app`** (yoki shaxsiy domen) |
| **Executable Name** | `boringNotch` | **`Dino`** |
| **XPC Helper** | `BoringNotchXPCHelper` | **`DinoXPCHelper`** |
| **Menu Bar Title** | `boringNotch` | **`Dino`** |
| **App Icon** | Eski notch ikonka | Zamonaviy yashil/neon rangdagi **Dino (T-Rex) silueti** |
| **UserDefaults Suite** | `boringNotchDefaults` | `dinoDefaults` |

---

## 📂 3. Fayllar va Kod Strukturasini Yangilash

1. **Info.plist va Build Settings:**
   * `CFBundleName`: `Dino`
   * `CFBundleDisplayName`: `Dino`
2. **Lokalizatsiya (Localizable.xcstrings):**
   * Matnlardagi barcha "boringNotch" so‘zlari "Dino" ga almashtiriladi.
3. **Assets.xcassets:**
   * Yangi 1024x1024 AppIcon to‘plamini yaratish.
   * Menu bar uchun zamonaviy qora/oq monoxrom Dino ikonkasi (`MenuBarIcon`).
