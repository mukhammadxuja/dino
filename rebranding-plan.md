# BoringNotch Fork — Rebranding + Yangi Xususiyatlar Rejasi

Bu rejasi sizning fork'ingizni "Boring Notch" dan o'z brendingizga to'liq o'zgartiradi, keyin esa ikkita asosiy yangi xususiyatni (Lock Screen Player va Pomodoro) xavfsiz bosqichlarda qo'shadi.

## 1) Joriy audit xulosasi (bugungi holat)

### Brend/identifikator nuqtalari topildi

- App/menu nomlari va restart matni @boringNotch/boringNotchApp.swift#32-40
- Settings oynasi nomi @boringNotch/components/Settings/SettingsWindowController.swift#43-59
- About sahifasi footeri/release yorlig'i va GitHub tugmasi @boringNotch/components/Settings/SettingsView.swift#841-909
- Onboarding app nomi havolalari va logo/jamoa rasmlari:
  - @boringNotch/components/Onboarding/WelcomeView.swift#24-30
  - @boringNotch/components/Onboarding/WelcomeView.swift#65-72
  - @boringNotch/components/Onboarding/OnboardingView.swift#43-110
- Loyiha metadati / signing identifikatori @boringNotch.xcodeproj/project.pbxproj#1236-1253 va #1289-1306
- Sparkle appcast URL'i @boringNotch/Info.plist#14-17
- README'dagi ommaviy brending va havolalar @README.md#1-163
- Asset katalogidagi brending manbalari:
  - App icon to'plami @boringNotch/Assets.xcassets/AppIcon.appiconset/Contents.json#1-69
  - Jamoa/footer asseti @boringNotch/Assets.xcassets/theboringteam.imageset/Contents.json#1-12
  - Logolar @boringNotch/Assets.xcassets/logo.imageset/Contents.json#1-12 va @boringNotch/Assets.xcassets/logo2.imageset/Contents.json#1-12

### So'rovga oid xususiyat arxitekturasi

- Lock-screen infratuzilmasi allaqachon mavjud:
  - Tugma kaliti: @boringNotch/models/Constants.swift#94
  - Settings tugma UI'si: @boringNotch/components/Settings/SettingsView.swift#1622-1624
  - App lock/unlock tadbirlarini qayta ishlash: @boringNotch/boringNotchApp.swift#89-107 va #335-350
- Media kanali modulli va kengaytirishga tayyor:
  - Menejer: @boringNotch/managers/MusicManager.swift#17-166
  - Protokol: @boringNotch/MediaControllers/MediaControllerProtocol.swift#12-29
  - Asosiy UI kirishi: @boringNotch/components/Notch/NotchHomeView.swift#112-319
  - Yopiq live activity ko'rinishi: @boringNotch/ContentView.swift#387-485
- Pomodoro xususiyati hozirda yo'q (pomodoro/timer domen kodi mavjud emas).

## 2) To'liq rebranding ro'yxati

## Faza A — Mahsulot Identifikatori (shart)

1. Yangi brend paketini aniqlang (nom, subtitle, tagline, uslub, rang, icon yo'nalishi).
2. Yakuniy texnik ID'larni tanlang:
   - `PRODUCT_BUNDLE_IDENTIFIER` (app + helper)
   - Team ID / signing strategiyasi
   - App display nomi va helper display nomi
3. Release/update kanalini tanlang:
   - Sparkle'ni saqlash yoki vaqtincha o'chirish
   - Agar Sparkle saqlansa: yangi appcast URL + yangi `SUPublicEDKey`

## Faza B — Ilova ichidagi matnlar va yorliqlar

1. Stringlarni o'zgartiring:
   - Menu bar nomi, restart matni, settings oynasi nomi
   - Onboarding tavsiflaridagi "Boring Notch" havolalari
   - About footer kredit qatori va eski jamoa nomlari
2. Tashqi havolalarni yangilang:
   - GitHub, website, Discord/Ko-fi (agar ishlatilsa)
3. Ixtiyoriy: brend konstantalarini markazlashtiring (qattiq kodlangan stringlardan qochish uchun).

## Faza C — Vizual rebranding

1. Assetlarni almashtiring:
   - AppIcon.appiconset rasmlari
   - `logo`, `logo2`, `theboringteam`, ixtiyoriy `Github` icon uslubi
2. Agar kerak bo'lsa, accent/theme moslamalarini yangilang (joriy advanced settings bilan mos).
3. Yorqin/qorong'i macOS ko'rinishlarida tekshiring.

## Faza D — Build/distributsiya rebrandingi

1. Xcode loyiha qiymatlarini yangilang:
   - Bundle ID'lar, display nomlari, tashkilot havolalari.
2. Bundle ID o'zgarishidan keyin entitlementslarni tekshiring:
   - Mach-lookup nomlari halaqit qilmayotganiga ishonch hosil qiling.
3. README'ni yangilang:
   - Nomi, clone URL, badge'lar, release'lar, skrinshotlar, roadmap matni.
4. Repository nomini o'zgartirish (ihtiyoriy lekin tavsiya etiladi).

## Faza E — Huquqiy/operatsion (tavsiya etiladi)

1. Ochiq kodli atributsiyani saqlashni tasdiqlang (credits/litsenziya fayllari).
2. Kontakt/yordam havolalari va maxfiylik matnlarini almashtiring.
3. Birinchi rebranding release notes'ini tayyorlang.

## 3) Yangi xususiyatlar yo'l xaritasi

### Xususiyat 1 — Lock Screen Player (mavjud lock-screen qo'llab-quvvatlashini yangilash)

Maqsad: macOS qulflanganda va `showOnLockScreen` yoqilganda, ixcham media kartasini xavfsiz boshqaruvlar bilan ko'rsating.

#### Qamrovi

- Qulflangan holat UI profili:
  - Minimal metadata (artwork/title/artist/progress)
  - Cheklangan harakatlar to'plami (play/pause, previous, next)
- Xavfsizlik cheklovlari:
  - Qulflangan ekranda media bo'lmagan interaktiv modullarni o'chirish (shelf, kamera, calendar tahrirlash va h.k.)
- Barcha kontrollerlarda mos keluvchi xulq-atvor (NowPlaying/Apple Music/Spotify/YouTube Music)

#### Tavsiya etilgan amalga oshirish yo'li

1. `isScreenLocked` holatini view model/koordinatorga kiritish va SwiftUI daraxtiga tarqatish.
2. `ContentView` marshrutizatsiyasida `LockScreenMediaView` ni alohida qulflangan holat sirti sifatida qo'shish.
3. Boshqaruvlar/harakatlarni qulflangan holatga qarab filtrlash (allowlist pattern).
4. Media/Advanced ostida settings kichik bo'limini qo'shish:
   - Qulflangan ekranda ko'rsatish (mavjud)
   - Qulflangan ekranda boshqaruvlarni yoqish
   - Artwork ni blur qilish / aniq metadatani yashirish (maxfiylik tugmasi)
5. Test matritsasi:
   - Qulflash/qulfdan chiqish o'tishlari ijro etilayotganda/to'xtatilganda
   - Ko'p displey xulq-atvori
   - Har bir media manba + manba bo'lmasa chora

### Xususiyat 2 — Pomodoro

Maqsad: focus taymerini notch live activity sifatida + ixtiyoriy ochiq-notch panel sifatida qo'shish.

#### Qamrovi (MVP)

- Sessiya turlari: Focus / Short Break / Long Break
- Standart presetlar: 25/5/15
- Boshqaruvlar: Start, Pause, Resume, Skip, Reset
- Relaunch da holatni saqlash (Defaults)
- Bosqich tugaganda bildirishnomalar/ovoz

#### Arxitektura taklifi

1. Yangi domen:
   - `PomodoroManager` (`ObservableObject`) chekli holat mashinasi bilan
   - `PomodoroSession`, `PomodoroPhase`, settings kalitlari `Constants.swift` da
2. UI sirtlari:
   - Yopiq notch ixcham countdown nishoni
   - Ochiq notch batafsil taymer kartasi (qolgan vaqt, bosqich, sikl soni)
3. Settings:
   - Pomodoro'ni yoqish
   - Davomiyliklar, keyingi bosqichni avtomatik boshlash, ovoz/haptics tugmalari
4. Ixtiyoriy v2:
   - Kunlik statistika, seriyalar, fokus hisoboti, calendar blok integratsiyasi

#### Integratsiya nuqtalari

- Music/battery sneak/expanding view'lar uchun ishlatiladigan koordinator naqshlaridan foydalaning.
- Bir vaqtda live activity'lar o'rtasidagi ziddiyatlarni aniqlik bilan hal qiling (masalan, music live activity ustunligi vs pomodoro nishoni).
- Taymer aniqligini monotonic-date hisoblashlari bilan saqlang (drift'dan saqlaning).

## 4) Tavsiya etilgan amalga oshirish tartibi

1. Asosiy identifikatorni rebranding qiling (nom, assetlar, havolalar, bundle ID'lar).
2. Build + run testlari.
3. Lock Screen Player xususiyati.
4. Pomodoro MVP.
5. README/docs tozalash + release tayyorgarligi.

## 5) Xavflar va yumshatish choralar

- Rebrandingdan keyin Sparkle buzilishi kalit/appcast nomos kelmasligi → imzo kalitini aylantiring + test feedni tekshiring.
- Bundle ID o'zgarishidan keyin helper/XPC muammolari → protokol nomlari va entitlementslarni qayta nomlangandan keyin tekshiring.
- Qulflangan ekran maxfiylik xavotirlari → sukut bo'yicha konservativ metadata ko'rsatish.
- Notch hududida xususiyat murakkabligining ustki-ustiga chiqishi → bir vaqtda live activity'lar uchun aniq prioritet qoidalari.

## 6) Keyingi amalga oshirish mumkin bo'lgan natijalar (tasdiqdan keyin)

1. Rebranding bosqichi 1: barcha ko'rinadigan stringlar + havolalar + settings/about/onboarding matnlari.
2. Rebranding bosqichi 2: loyiha ID'lari/imzo joylari + docs tozalash.
3. Lock Screen Player MVP.
4. Pomodoro MVP + settings.
5. Regressiya tekshiruvi ro'yxati va release notes loyihasi.

## Ochiq savollar (kodlashdan oldin)

1. Yangi app nomi nima bo'ladi (aniq yozilishi bilan)?
2. Bundle ID qanday bo'lsin? (masalan `com.mukhammadxuja.notchflow`)
3. Sparkle update kanali ishlasinmi yoki vaqtincha o'chiraylikmi?
4. Lock screen'da qaysi ma'lumotlar ko'rsatilsin (track title/artist/artwork) va qaysilar yashirilsin?
5. Pomodoro default presetlari 25/5/15 qoladimi yoki boshqa?
