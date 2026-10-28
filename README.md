# Gəlir-Çıxar

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
