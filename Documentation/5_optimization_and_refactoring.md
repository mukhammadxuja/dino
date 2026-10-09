# ⚡️ Optimizatsiya va Refaktoring Rejasi (Optimization & Performance)

## 📌 Kirish
Ilova ochiq manbali karkasdan kengaytirilgani sababli, `ContentView.swift` va `boringNotchApp.swift` haddan tashqari katta ("God Objects") holga kelgan. Bu SwiftUI re-rendering siklini og‘irlashtirib, keraksiz CPU va batareya resursini sarflamoqda.

Ushbu hujjat ilovani **0.0% CPU (Idle holatda)** va **yengil arxitektura**ga olib chiqish bo‘yicha aniq rejani belgilaydi.

---

## 🔍 1. Aniqlangan Muammolar va Ularning Yechimi

### 🔴 Muammo 1: `ContentView.swift` dagi View Invalidation (1,495 qator)
* **Sababi:** `ContentView` ichida 8 ta `@ObservedObject` bor. Masalan, musiqa to‘lqini har 60fps da yoki taymer har 100ms da yangilanganda, butun 1,500 qatorli view qayta render bo‘lmoqda.
* **Yechim:** **"Container & Slot"** shabloniga o‘tish. `ContentView` faqat konteyner bo‘ladi va o‘zida hech qanday ortiqcha managerlarni saqlamaydi:
  ```swift
  struct DinoContainerView: View {
      @ObservedObject var coordinator = DinoCoordinator.shared

      var body: some View {
          ZStack {
              switch coordinator.activeSlot {
              case .music: MusicSlotView()
              case .pomodoro: PomodoroSlotView()
              case .weather: WeatherSlotView()
              case .hud(let type): InlineHUDView(type: type)
              case .shelf: ShelfView()
              case .idle: IdleCapsuleView()
              }
          }
          .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.78), value: coordinator.activeSlot)
      }
  }
  ```
  Endi musiqa o‘zgarsa faqat `MusicSlotView`, taymer o‘zgarsa faqat `PomodoroSlotView` render bo‘ladi. Qolgan tizim umuman yuklanmaydi.

---

### 🔴 Muammo 2: Timers va Metal Shaderlarning To‘xtatilmasligi
* **Sababi:** Musiqa pauza qilinganda yoki taymer to‘xtaganda ham ba'zi render looplar va timerlar fonda ishlab turishi mumkin.
* **Yechim:** Har bir managerda faoliyat to‘xtashi bilan timerni `.invalidate()` qilish va `MetalView` fps'ini 0 ga tushirish (Sleep Mode).

---

### 🔴 Muammo 3: `boringNotchApp.swift` (1,625 qator)
* **Sababi:** Window boshqaruvi, ekran sozlamalari, hotkeylar va menyular bitta joyga yig‘ilgan.
* **Yechim:** Vazifalarni alohida sinflarga bo‘lish:
  * `WindowManager.swift` — Oynalarni yaratish, ekranga joylashtirish.
  * `ScreenObserver.swift` — Tashqi monitor ulanganini aniqlash.
  * `HotKeyManager.swift` — Klaviatura yorliqlarini boshqarish.
  * `AppDelegate.swift` — Faqat ilova hayot siklini (Lifecycle) boshqaradi.

---

## 📋 2. Qadam-baqadam Refaktoring Rejasi

```
[1. Coordinator Yaratish] ──> [2. Viewlarni Bo'laklash] ──> [3. Timerni Tozalash] ──> [4. Profiling]
```

1. **1-Qadam: `DinoCoordinator` (Singleton) yaratish**
   * Barcha holatlar (`P1, P2, P3, P4`) va o‘tish mantiqi shu yerga ko‘chiriladi.
2. **2-Qadam: Kichik Viewlarni ajratish**
   * `MusicSlotView.swift`
   * `PomodoroSlotView.swift`
   * `WeatherSlotView.swift`
   * `InlineHUDView.swift`
3. **3-Qadam: Memory Leaks va Tasklarni tozalash**
   * `Task { @MainActor in ... }` deb ochilgan va bekor qilinmagan (un-cancelled) barcha vazifalarni tozalash.
4. **4-Qadam: Xcode Instruments bilan o‘lchash**
   * `Time Profiler` — CPU 0.0% - 0.5% bo‘lishini tekshirish.
   * `Allocations & Leaks` — Xotirada qolib ketuvchi (retain cycle) obyektlarni yo‘qotish.
