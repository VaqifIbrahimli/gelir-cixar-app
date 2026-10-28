# Gəlir-Çıxar

**Azərbaycanca** · [English](#english)

Şəxsi gəlir və xərcləri izləmək üçün Android tətbiqi. Flutter ilə yazılıb, məlumatlar yalnız telefonda saxlanılır.

## Yükləmə

Son versiyanı [Releases](https://github.com/VaqifIbrahimli/gelir-cixar-app/releases/latest) səhifəsindən endirin:

- **`...-arm64.apk`** müasir telefonların əksəriyyəti üçündür.
- **`...-universal.apk`** isə arm64 versiyası quraşdırılmayanda istifadə olunur.

Quraşdırma: APK faylını telefonda açın, "naməlum mənbələrdən quraşdırma" icazəsini verin və **Quraşdır** düyməsini basın. Yeniləyərkən həmişə eyni növ faylı (arm64 və ya universal) seçin. Əks halda Android yeniləməni qəbul etməyəcək.

## İmkanlar

- Gəlir, xərc və hesablar arası köçürmə
- Bir neçə hesab: nağd, kart, bank, yığım
- Bir neçə valyuta: AZN, USD, EUR, RUB, TRY
- **Avtomatik məzənnə** AMB-dən (cbar.az) gəlir. İstəyə bağlıdır və standart olaraq söndürülüb. İstənilən məzənnəni əl ilə də dəyişmək olar.
- **Kənar yerlər:** evdə saxlanan nağd pul, qohumda olan pul, bank depoziti və qızıl. Bunlar ümumi sərvətə daxil edilir.
- Kateqoriyalar və aylıq büdcələr. Büdcənin 80% və 100%-i dolanda xəbərdarlıq gəlir.
- Hesabatlar: kateqoriyalar üzrə dairəvi qrafik, aylıq gəlir-xərc və balansın dəyişməsi
- CSV, Excel və PDF formatında export, JSON ehtiyat nüsxə və bərpa
- PIN və barmaq izi ilə kilid
- Azərbaycan və İngilis dili, açıq və tünd tema, Material You rəngləri

## Məxfilik

- Bütün məlumatlar yalnız telefonda saxlanılır. Hesab, reklam və analitika yoxdur.
- İnternet yalnız avtomatik məzənnə açıq olduqda işlədilir və yalnız `www.cbar.az` saytından məzənnə cədvəli yüklənir. Heç bir şəxsi məlumat göndərilmir.
- Android-in avtomatik ehtiyat nüsxəsi söndürülüb, ekran görüntüsü standart olaraq qadağandır.

## Mənbədən yığmaq

Lazımdır: Flutter 3.47+ və Android SDK.

```bash
flutter pub get
dart run build_runner build
flutter gen-l10n
flutter test
flutter build apk --release --split-per-abi
```

Release imzası üçün `android/key.properties` faylı lazımdır. Bu fayl repoya daxil edilmir. Fayl olmadıqda build debug açarı ilə imzalanır.

---

<a id="english"></a>

## English

[Azərbaycanca](#gəlir-çıxar) · **English**

Gəlir-Çıxar ("Income-Expense") is an Android app for tracking personal income and spending. It is built with Flutter, and all data stays on your phone.

### Download

Get the latest version from the [Releases](https://github.com/VaqifIbrahimli/gelir-cixar-app/releases/latest) page:

- **`...-arm64.apk`** for most modern phones.
- **`...-universal.apk`** if the arm64 build won't install.

To install, open the APK on your phone, allow installing from unknown sources, and tap **Install**. When updating, always pick the same kind of file you installed before (arm64 or universal), or Android will refuse the update.

### Features

- Income, expenses and transfers between accounts
- Multiple accounts: cash, card, bank, savings
- Multiple currencies: AZN, USD, EUR, RUB, TRY
- **Automatic exchange rates** from the Central Bank of Azerbaijan (cbar.az). This is optional and off by default. Any rate can still be set by hand.
- **Money held elsewhere** ("Kənar yerlər"): cash at home, money with relatives, bank deposits and gold. It counts towards your net worth, but not towards your spendable balance.
- Categories and monthly budgets, with alerts at 80% and 100% of a budget
- Reports: a pie chart by category, monthly income and expense, and the balance trend
- Export to CSV, Excel and PDF, and full JSON backup and restore
- PIN and fingerprint lock
- Azerbaijani and English interface, light and dark themes, Material You colours

### Privacy

- All data stays on the phone. There are no accounts, ads or analytics.
- The internet is used only when automatic rates are turned on, and only to download the rate table from `www.cbar.az`. No personal data is sent.
- Android auto-backup is turned off, and screenshots are blocked by default.

### Building from source

You need Flutter 3.47+ and the Android SDK.

```bash
flutter pub get
dart run build_runner build
flutter gen-l10n
flutter test
flutter build apk --release --split-per-abi
```

Release signing needs an `android/key.properties` file, which is not in the repository. Without it, the build is signed with the debug key.
