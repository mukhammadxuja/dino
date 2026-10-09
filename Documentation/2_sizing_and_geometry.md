# 📐 O‘lchamlar va Geometriya Standartlari (Sizing & Geometry)

## 📌 Kirish
**Dino** ilovasida elementlarning xunuk yoki nomutanosib ko‘rinib qolmasligining asosi — qat'iy va matematik jihatdan to‘g‘ri hisoblangan geometriya tizimidir. Ilova har xil ekranlarda (MacBook Air 13"/15", Pro 14"/16", 24"-32" tashqi monitorlar) ikki xil asosiy rejimda ishlaydi:
1. **Built-in Screen (Fizik Notch Mode)**
2. **External Screen / Non-Notch (Floating Island Mode)**

---

## 💻 1. Built-in MacBook (Fizik Notch) O‘lchamlari

MacBook ekranida kamera va datchiklar qora plastik orqasida joylashgan. Shuning uchun markaz har doim bo‘sh qoldirilib, elementlar uning ikki yonidagi "qanotlar"ga (Wings) joylashadi.

```
                  ┌── [ Fizik Kamera ] ──┐
   [ Chap Qanot ] │                      │ [ O‘ng Qanot ]
                  └──────────────────────┘
```

### O‘lchamni hisoblash formulasi:
* **Fizik Notch Kengligi:**
  ```swift
  let screen = NSScreen.main
  let leftPadding = screen.auxiliaryTopLeftArea?.width ?? 0
  let rightPadding = screen.auxiliaryTopRightArea?.width ?? 0
  let physicalNotchWidth = screen.frame.width - leftPadding - rightPadding + 4
  ```
* **Balandlik:**
  ```swift
  let physicalNotchHeight = screen.safeAreaInsets.top // Odatda Air'da 32pt, Pro'da 34-36pt
  ```
* **Feat faol bo‘lgandagi umumiy kenglik:**
  ```
  Total Width = physicalNotchWidth + (LeftWingWidth + RightWingWidth)
  ```
* **Simmetriya qoidasi:** Kamera markazda bo‘lgani sababli, chap va o‘ng qanotlar vizual jihatdan bir xil kenglikda (`symmetric padding`) kengayishi shart.

---

## 🖥️ 2. External Display / Island (Tashqi Monitor) O‘lchamlari

Tashqi monitorlarda Menu Bar ichida erkin suzuvchi (Floating Island) kapsula sifatida joylashadi.

* **Balandligi (Height):** `24pt` (Standart tashqi monitorlarda macOS Menu Bar balandligi 24–25pt bo‘ladi).
* **Radius:** To‘liq yumaloq (`Capsule()` yoki `cornerRadius: 12pt`).
* **Joylashuvi:** Ekranning yuqori markazida, Menu Bar ichida yuqori va pastki chegaralarga tegilmasdan turadi.
* **Default (Bo‘sh) Kenglik:** `70pt` (Kichik qora kapsula).

---

## 🗂️ 3. Holatlar Bo‘yicha Standart O‘lchamlar (Sizing Presets)

### A. Closed / Pill Holati (Ixcham rejim)
Har bir feat o‘z ma'lumot hajmiga qarab dinamik kengayadi:

| Feat | Chap tomon | O‘ng tomon | Umumiy Kenglik (Island) |
|---|---|---|---|
| **☀️ Ob-havo** | `☀️` Ikonka (16pt) | `25°` (22pt) | **~150pt** |
| **🍅 Pomodoro** | `🍅` Ikonka (16pt) | `24:50` (38pt) | **~175pt** |
| **🎵 Musiqa** | `|||` Visualizer (22pt) | `🖼️` Cover (20pt) | **~190pt** |
| **🔋 Batareya** | `⚡️` Zaryad (14pt) | `85%` (28pt) | **~160pt** |
| **📥 Yuklama** | `⬇️ 45%` (36pt) | `12 MB/s` (45pt) | **~220pt** |

### B. Open / Expanded Holati (Kengaytirilgan rejim)
Foydalanuvchi orolchaga bosganda yoki shortcut orqali kengayganda har xil tasodifiy o‘lchamlarda ochilmasligi uchun **3 ta qat'iy standart karta (Preset)** belgilanadi:

```
┌────────────────────────────────────────────────────────┐
│ 1. Compact Sheet (280 x 90 pt)                         │
│    -> Tezkor boshqaruv, Batareya detali, Mini Taymer   │
├────────────────────────────────────────────────────────┤
│ 2. Standard Card (360 x 145 pt)                        │
│    -> Musiqa Pleyeri (Art + Sliders), Ob-havo 5 kunlik │
├────────────────────────────────────────────────────────┤
│ 3. Large Hub (440 x 210 pt)                            │
│    -> Taqvim ro'yxati, Shelf (Fayllar javoni)          │
└────────────────────────────────────────────────────────┘
```

---

## 🎬 4. Animatsiya va O‘tish Qoidalari
O‘lcham o‘zgarishida hech qachon qattiq (snap/jump) o‘tish bo‘lmasligi kerak.
* **Standart Spring Animatsiyasi:**
  ```swift
  .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.78, blendDuration: 0.25), value: activeState)
  ```
* Bu orolchani Apple Dynamic Island kabi silliq, elastik va tirik his qildiradi.
