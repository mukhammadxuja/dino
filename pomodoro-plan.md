# Pomodoro qo‘shimchasi — Settings + Notch integratsiya rejasi

Bu reja BoringNotch ichiga Pomodoro funksiyasini alohida **Settings sahifasi**, **notch ichidagi bo‘lim**, va **animatsion holatlar** bilan bosqichma-bosqich, regressiyasiz kiritishni ko‘zlaydi.

## 1) Joriy holat (kod bazadagi tayanch nuqtalar)

- Settings sidebar va detail routingi: `SettingsView` (`selectedTab` + `NavigationLink`) ichida boshqariladi.
- Settings ichidagi bo‘limlar hozir bir faylda jamlangan (General, Media, Calendar, HUD, va h.k.).
- Global sozlamalar kalitlari `Defaults.Keys` orqali `Constants.swift` da markazlashgan.
- Notch ochiq/yopiq holat, view marshrutizatsiyasi, hover/gesture va transitionlar `ContentView` + `BoringViewModel` + `BoringViewCoordinator`da.
- Header ichidagi tezkor ikon/tugmalar (settings, battery, mirror) `BoringHeader`da.

## 2) MVP qamrov (aniq deliverable)

1. **Settings’da yangi “Pomodoro” sahifasi**
   - Sidebar’da yangi tab.
   - Pomodoro konfiguratsiyasi uchun alohida form.

2. **Notch’da Pomodoro bo‘limi**
   - Ochiq notch holatida Pomodoro kartasi/bo‘limi.
   - Zarur bo‘lsa tablar oqimiga Pomodoro view qo‘shish.

3. **Animatsiyalar**
   - Start/Pause/Resume/Complete holatlariga mos vizual o‘tishlar.
   - Notch ochilish-yopilish animatsiyalari bilan konflikt qilmaydigan yagona timing modeli.

4. **Persist + lifecycle**
   - Sozlamalar va timer holatini relaunchdan keyin tiklash.

## 3) Bosqichma-bosqich implementatsiya rejasi

### 1-bosqich — Domen modeli va state machine

- `PomodoroPhase` (focus, shortBreak, longBreak), `PomodoroState` (idle, running, paused, completed) modelini aniqlash.
- `PomodoroManager` (`ObservableObject`) yaratish:
  - `start()`, `pause()`, `resume()`, `skip()`, `reset()` API.
  - Monotonic time hisoblash (driftni kamaytirish).
  - Fazalar almashinuvi (focus -> shortBreak; n-sikldan keyin longBreak).

**Muhim:** UI emas, avval managerni barqaror qilish — keyingi barcha qatlamlar shu APIga tayanadi.

### 2-bosqich — Defaults kalitlari va konfiguratsiya

`Constants.swift`ga yangi kalitlar qo‘shish:
- `pomodoroEnabled`
- `pomodoroFocusMinutes`
- `pomodoroShortBreakMinutes`
- `pomodoroLongBreakMinutes`
- `pomodoroAutoStartBreaks`
- `pomodoroAutoStartFocus`
- `pomodoroCycleBeforeLongBreak`
- `pomodoroNotchCompactMode` (ixtiyoriy)
- `pomodoroPersistedSession` (kodlangan holat)

**Muhim:** default qiymatlar UXga tayyor bo‘lishi kerak (masalan 25/5/15).

### 3-bosqich — Settings’da yangi “Pomodoro” sahifasi

- `SettingsView` sidebarga `NavigationLink(value: "Pomodoro")` qo‘shish.
- `switch selectedTab`ga `case "Pomodoro"` qo‘shish.
- Yangi `struct PomodoroSettings: View`:
  - Enable toggle
  - Focus/Break duration steppers yoki sliders
  - Auto-start toggles
  - Long break cycle
  - Notch’da ko‘rinish rejimi (compact/full)

**Muhim:** validation (min/max) qo‘yish; noto‘g‘ri qiymatlar managerga tushmasligi kerak.

### 4-bosqich — Notch routing va UI integratsiya

- `NotchViews`ga `.pomodoro` qo‘shish (agar alohida tab kerak bo‘lsa).
- `TabSelectionView`ga Pomodoro tab qo‘shish (feature yoqilganida ko‘rinadigan).
- `ContentView` ichidagi `switch coordinator.currentView`ga `PomodoroNotchView` ulash.

**Muhim:** Shelf/Home oqimi buzilmasin; Pomodoro bo‘limi shartli render qilinsin (`pomodoroEnabled`).

### 5-bosqich — Ochiq notch uchun Pomodoro komponentlari

Yangi komponentlar:
- `PomodoroNotchView` (asosiy container)
- `PomodoroCountdownRing` yoki progress bar
- `PomodoroControls` (start/pause/resume/skip/reset)
- `PomodoroPhaseBadge` (focus/break holatini ko‘rsatish)

**Muhim:** layout mavjud NotchHome spacing/height standartiga mos bo‘lishi kerak.

### 6-bosqich — Animatsiya dizayni va implementatsiya

- Holatga bog‘liq transitionlar:
  - Idle -> Running: scale+opacity (tez, motivatsion)
  - Running -> Paused: blur/opacity yengil pasayish
  - Phase complete: pulse yoki glow (qisqa feedback)
- Mavjud `interactiveSpring` / `.smooth` bilan uyg‘un timing tanlash.
- Bir joyda boshqarish uchun Pomodoro animation constants ajratish.

**Muhim:** `ContentView`dagi notch open/close animation bilan ikki marta animatsiya berib yubormaslik (double animation risk).

### 7-bosqich — Notification / haptics / signal

- Fazaning tugashida local notification (macOS) trigger.
- Mavjud haptics setting bilan integratsiya (agar yoqilgan bo‘lsa feedback berish).
- Ixtiyoriy: qisqa system sound.

**Muhim:** notification permission denied holati uchun fallback UX bo‘lishi kerak.

### 8-bosqich — Persist va recovery

- App relaunch bo‘lganda active sessionni tiklash.
- Time-based recompute qilish (qolgan vaqtni storage’dan to‘g‘ridan o‘qib emas, timestampdan hisoblash).

**Muhim:** sleep/wake yoki system time change holatlarini ham to‘g‘ri qamrab olish.

### 9-bosqich — Test va regressiya checklist

- Unit testlar (manager state machine):
  - start/pause/resume/skip/reset
  - cycle -> longBreak transition
  - persistence restore
- UI regressiya:
  - Settingsdan qiymat o‘zgartirish -> notchda darhol aks etishi
  - Notch open/close paytida Pomodoro view transitionlari
  - Pomodoro o‘chiq holatda UI elementlar yashirilishi

## 4) Texnik xavflar va yumshatish

1. **Animation clash** (`ContentView` + component-level animation)
   - Yechim: bitta manbadan timing constants; keraksiz implicit animationlarni cheklash.
2. **Timer drift**
   - Yechim: elapsed time’ni `Date`/timestamp asosida hisoblash.
3. **Route complexity (home/shelf/pomodoro)**
   - Yechim: `currentView` o‘tish qoidalarini aniq yozish (feature flag bilan).
4. **Settings bir faylda juda kattalashishi**
   - Yechim: Pomodoro settingsni alohida component faylga ajratish.

## 5) Tavsiya etilgan implementatsiya tartibi (qisqa)

1. Manager + model + Defaults.
2. Settings’da Pomodoro sahifa.
3. Notch routing + Pomodoro view.
4. Animatsiyalarni yakunlash.
5. Persist/recovery + notification.
6. Test/regressiya.

## 6) Ochiq qarorlar (kodlashdan oldin tasdiqlash kerak)

1. Default presetlar: **25/5/15** yakuniymi?
2. Pomodoro notchda alohida tab bo‘ladimi yoki Home ichida card bo‘lib turadimi?
3. Phase tugaganda faqat notificationmi, yoki tovush/haptic ham default yoqilsinmi?
4. Auto-start break/focus default holati qanday bo‘lsin?
