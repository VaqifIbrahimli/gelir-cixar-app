// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Azerbaijani (`az`).
class AppLocalizationsAz extends AppLocalizations {
  AppLocalizationsAz([String locale = 'az']) : super(locale);

  @override
  String get appTitle => 'Gəlir-Çıxar';

  @override
  String get navHome => 'Ana səhifə';

  @override
  String get navTransactions => 'Əməliyyatlar';

  @override
  String get navReports => 'Hesabatlar';

  @override
  String get navBudgets => 'Büdcələr';

  @override
  String get navSettings => 'Ayarlar';

  @override
  String get genericError => 'Xəta baş verdi';

  @override
  String get cancel => 'Ləğv et';

  @override
  String get save => 'Saxla';

  @override
  String get delete => 'Sil';

  @override
  String get close => 'Bağla';

  @override
  String get confirm => 'Təsdiqlə';

  @override
  String get clear => 'Təmizlə';

  @override
  String get more => 'Daha çox';

  @override
  String get undo => 'Geri al';

  @override
  String get all => 'Hamısı';

  @override
  String get seeAll => 'Hamısı';

  @override
  String get total => 'Ümumi';

  @override
  String get today => 'Bu gün';

  @override
  String get yesterday => 'Dünən';

  @override
  String get income => 'Gəlir';

  @override
  String get expense => 'Xərc';

  @override
  String get net => 'Net';

  @override
  String get txTypeIncome => 'Gəlir';

  @override
  String get txTypeExpense => 'Xərc';

  @override
  String get txTypeTransfer => 'Transfer';

  @override
  String get uncategorized => 'Kateqoriyasız';

  @override
  String get totalBalance => 'Ümumi balans';

  @override
  String get showBalance => 'Balansı göstər';

  @override
  String get hideBalance => 'Balansı gizlət';

  @override
  String get balanceHidden => 'Balans gizlədilib';

  @override
  String get negativeBalance => 'Mənfi balans';

  @override
  String thisMonth(String month) {
    return 'Bu ay: $month';
  }

  @override
  String get recentTransactions => 'Son əməliyyatlar';

  @override
  String get accounts => 'Hesablar';

  @override
  String get account => 'Hesab';

  @override
  String get addAccount => 'Hesab əlavə et';

  @override
  String get newAccount => 'Yeni hesab';

  @override
  String get editAccount => 'Hesabı redaktə et';

  @override
  String get accountNotFound => 'Hesab tapılmadı';

  @override
  String get accountType => 'Hesabın növü';

  @override
  String get accountTypeCash => 'Nağd';

  @override
  String get accountTypeCard => 'Kart';

  @override
  String get accountTypeBank => 'Bank hesabı';

  @override
  String get accountTypeSavings => 'Əmanət';

  @override
  String get currency => 'Valyuta';

  @override
  String get currencyLockedHint =>
      'Əməliyyatı olan hesabın valyutası dəyişdirilə bilməz.';

  @override
  String get initialBalance => 'Başlanğıc balans';

  @override
  String get color => 'Rəng';

  @override
  String colorN(int n) {
    return 'Rəng $n';
  }

  @override
  String get name => 'Ad';

  @override
  String get nameRequired => 'Ad daxil edin';

  @override
  String get archive => 'Arxivlə';

  @override
  String get unarchive => 'Arxivdən çıxar';

  @override
  String get archived => 'arxivdə';

  @override
  String archivedCount(int count) {
    return 'Arxivlənmiş ($count)';
  }

  @override
  String get deleteAccountTitle => 'Hesab silinsin?';

  @override
  String get deleteAccountBody => 'Bu hesab birdəfəlik silinəcək.';

  @override
  String get deleteAccountUsedBody =>
      'Bu hesabda əməliyyatlar var, ona görə silinmir, arxivlənəcək. Tarixçə saxlanılır.';

  @override
  String get accountDeleted => 'Hesab silindi';

  @override
  String get accountArchived => 'Hesab arxivləndi';

  @override
  String get emptyAccountsTitle => 'Hesab əlavə edin';

  @override
  String get categories => 'Kateqoriyalar';

  @override
  String get category => 'Kateqoriya';

  @override
  String get newCategory => 'Yeni kateqoriya';

  @override
  String get editCategory => 'Kateqoriyanı redaktə et';

  @override
  String get categoryNotFound => 'Kateqoriya tapılmadı';

  @override
  String get nameAz => 'Ad (Azərbaycanca)';

  @override
  String get nameEn => 'Ad (İngiliscə)';

  @override
  String get nameEnHint => 'Boş qalsa, azərbaycanca ad göstərilir';

  @override
  String get icon => 'İkon';

  @override
  String transactionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count əməliyyat',
      zero: 'Əməliyyat yoxdur',
    );
    return '$_temp0';
  }

  @override
  String get deleteCategoryTitle => 'Kateqoriya silinsin?';

  @override
  String get deleteCategoryBody => 'Bu kateqoriya birdəfəlik silinəcək.';

  @override
  String get deleteCategoryUsedBody =>
      'Bu kateqoriya istifadə olunur, ona görə silinmir, arxivlənəcək.';

  @override
  String get categoryDeleted => 'Kateqoriya silindi';

  @override
  String get categoryArchived => 'Kateqoriya arxivləndi';

  @override
  String get emptyCategoriesTitle => 'Kateqoriya yoxdur';

  @override
  String get addTransaction => 'Əməliyyat əlavə et';

  @override
  String get newTransaction => 'Yeni əməliyyat';

  @override
  String get editTransaction => 'Əməliyyatı redaktə et';

  @override
  String get transactionNotFound => 'Əməliyyat tapılmadı';

  @override
  String get emptyTransactionsTitle => 'Hələ əməliyyat yoxdur';

  @override
  String get emptyTransactionsBody => 'İlk gəlir və ya xərcinizi əlavə edin.';

  @override
  String get emptyFilteredTitle => 'Uyğun nəticə tapılmadı';

  @override
  String get resetFilters => 'Filtrləri sıfırla';

  @override
  String get search => 'Axtar';

  @override
  String get closeSearch => 'Axtarışı bağla';

  @override
  String get searchNotes => 'Qeydlərdə axtar';

  @override
  String get allAccounts => 'Bütün hesablar';

  @override
  String get allCategories => 'Bütün kateqoriyalar';

  @override
  String get dateRange => 'Tarix';

  @override
  String get date => 'Tarix';

  @override
  String get note => 'Qeyd';

  @override
  String get addNote => 'Qeyd əlavə et';

  @override
  String get noteHint => 'Məsələn: Bravo market';

  @override
  String get fromAccount => 'Haradan';

  @override
  String get toAccount => 'Haraya';

  @override
  String get amountSent => 'Göndərilən';

  @override
  String get amountReceived => 'Alınan';

  @override
  String get transactionDeleted => 'Əməliyyat silindi';

  @override
  String get deleteTransactionTitle => 'Əməliyyat silinsin?';

  @override
  String get deleteTransactionBody => 'Bu əməliyyat silinəcək.';

  @override
  String get enterAmount => 'Məbləğ daxil edin';

  @override
  String get invalidAmount => 'Yanlış məbləğ';

  @override
  String get enterReceivedAmount => 'Alınan məbləği daxil edin';

  @override
  String get selectAccount => 'Hesab seçin';

  @override
  String get selectToAccount => 'Hədəf hesabı seçin';

  @override
  String get sameAccountError => 'Hesablar fərqli olmalıdır';

  @override
  String get selectCategory => 'Kateqoriya seçin';

  @override
  String get backspace => 'Sil';

  @override
  String get backspaceHint => 'Basıb saxlayın: hamısını sil';

  @override
  String get plus => 'Üstəgəl';

  @override
  String get plusHint => 'Basıb saxlayın: vurma (×)';

  @override
  String get minus => 'Çıx';

  @override
  String get minusHint => 'Basıb saxlayın: bölmə (÷)';

  @override
  String get decimalPoint => 'Onluq ayırıcı';

  @override
  String get equals => 'Bərabərdir';

  @override
  String get enterPin => 'PIN kodu daxil edin';

  @override
  String get enterCurrentPin => 'Hazırkı PIN kodu daxil edin';

  @override
  String get createPin => 'Yeni PIN kod yaradın';

  @override
  String get confirmPin => 'PIN kodu təkrar daxil edin';

  @override
  String get pinLengthHint => '4–6 rəqəm, sonra ✓ basın';

  @override
  String get pinMismatch => 'PIN kodlar uyğun gəlmir. Yenidən cəhd edin.';

  @override
  String get pinSetupIntro =>
      'Məlumatlarınızı qorumaq üçün PIN kod təyin edin. Kilidi sonra Ayarlarda söndürə bilərsiniz.';

  @override
  String pinDigitsEntered(int entered, int total) {
    return '$entered / $total rəqəm daxil edilib';
  }

  @override
  String wrongPinAttemptsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Yanlış PIN. $count cəhd qalıb',
      zero: 'Yanlış PIN',
    );
    return '$_temp0';
  }

  @override
  String lockedOutFor(int seconds) {
    return 'Çox sayda yanlış cəhd. $seconds saniyə gözləyin.';
  }

  @override
  String get useFingerprint => 'Barmaq izi ilə aç';

  @override
  String get biometricReason => 'Gəlir-Çıxar-ı açmaq üçün təsdiqləyin';

  @override
  String get biometricEnableReason =>
      'Barmaq izi ilə açılışı aktivləşdirmək üçün təsdiqləyin';

  @override
  String get biometricUnavailable =>
      'Bu cihazda barmaq izi qeydiyyatda deyil və ya dəstəklənmir';

  @override
  String get settingsGeneral => 'Ümumi';

  @override
  String get settingsSecurity => 'Təhlükəsizlik';

  @override
  String get settingsData => 'Məlumat';

  @override
  String get settingsAbout => 'Haqqında';

  @override
  String get language => 'Dil';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Sistem';

  @override
  String get themeLight => 'Açıq';

  @override
  String get themeDark => 'Tünd';

  @override
  String get baseCurrency => 'Əsas valyuta';

  @override
  String get appLock => 'Tətbiq kilidi';

  @override
  String get appLockSubtitle => 'Açılışda PIN kod tələb et';

  @override
  String get changePin => 'PIN kodu dəyiş';

  @override
  String get fingerprint => 'Barmaq izi';

  @override
  String get fingerprintSubtitle => 'PIN əvəzinə barmaq izi ilə aç';

  @override
  String get about => 'Tətbiq haqqında';

  @override
  String get aboutBody =>
      'Şəxsi gəlir və xərclərin oflayn izlənməsi. Bütün məlumatlar yalnız bu cihazda saxlanılır.';

  @override
  String versionN(String version) {
    return 'Versiya $version';
  }

  @override
  String get addBudget => 'Büdcə əlavə et';

  @override
  String get editBudget => 'Büdcəni redaktə et';

  @override
  String get deleteBudgetTitle => 'Büdcə silinsin?';

  @override
  String get budgetLimit => 'Aylıq limit';

  @override
  String get budgetTotal => 'Ümumi büdcə';

  @override
  String get budgetSummary => 'Büdcə xülasəsi';

  @override
  String budgetRemaining(String amount) {
    return 'Qalıb: $amount';
  }

  @override
  String budgetOverBy(String amount) {
    return 'Aşıb: $amount';
  }

  @override
  String get budgetStateWarning => 'xəbərdarlıq';

  @override
  String get budgetStateOver => 'limit aşıldı';

  @override
  String budgetSemantics(String name, int percent) {
    return '$name büdcəsi, $percent faiz istifadə olunub';
  }

  @override
  String budgetDailyAllowance(String amount, int days) {
    return 'Gündəlik limit: $amount (qalan $days gün)';
  }

  @override
  String budgetsNearLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kateqoriya limitə yaxındır və ya aşıb',
      one: '1 kateqoriya limitə yaxındır və ya aşıb',
    );
    return '$_temp0';
  }

  @override
  String get budgetsCopyLastMonth => 'Keçən ayın büdcələrini köçür';

  @override
  String budgetsCopied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count büdcə köçürüldü',
      one: '1 büdcə köçürüldü',
    );
    return '$_temp0';
  }

  @override
  String get budgetsCopyNone => 'Köçürüləcək büdcə yoxdur';

  @override
  String get budgetAllCategoriesUsed =>
      'Bütün xərc kateqoriyalarının bu ay üçün büdcəsi var.';

  @override
  String get emptyBudgetsTitle => 'Büdcə qurulmayıb';

  @override
  String get emptyBudgetsBody =>
      'Kateqoriyalar üçün aylıq limit təyin edin və xərclərinizi izləyin.';

  @override
  String get positiveAmountRequired => 'Müsbət məbləğ daxil edin';

  @override
  String get previousMonth => 'Əvvəlki ay';

  @override
  String get nextMonth => 'Növbəti ay';

  @override
  String budgetAlertWarningTitle(String name) {
    return '$name: büdcə limitinə yaxınlaşır';
  }

  @override
  String budgetAlertWarningBody(int percent, String amounts) {
    return 'Limitin $percent%-i istifadə olunub ($amounts)';
  }

  @override
  String budgetAlertOverTitle(String name) {
    return '$name: büdcə limiti aşıldı';
  }

  @override
  String budgetAlertOverBody(String amounts) {
    return 'Xərclənib: $amounts';
  }

  @override
  String get notificationChannelName => 'Büdcə xəbərdarlıqları';

  @override
  String get notificationChannelDescription =>
      'Büdcə limitinin 80% və 100%-nə çatdıqda';

  @override
  String get budgetNotifications => 'Büdcə bildirişləri';

  @override
  String get budgetNotificationsSubtitle =>
      'Limitin 80% və 100%-ində bildiriş göndər';

  @override
  String get notificationsDenied =>
      'Bildiriş icazəsi verilmədi. Onu sistem ayarlarından aça bilərsiniz.';

  @override
  String get periodThisMonth => 'Bu ay';

  @override
  String get periodLastMonth => 'Keçən ay';

  @override
  String get periodThisYear => 'Bu il';

  @override
  String get periodCustom => 'Xüsusi';

  @override
  String get emptyReportsTitle => 'Bu dövr üçün məlumat yoxdur';

  @override
  String get otherCategories => 'Digər';

  @override
  String get reportsByMonth => 'Aylar üzrə';

  @override
  String monthsN(int count) {
    return '$count ay';
  }

  @override
  String averageMonthlyExpense(String amount) {
    return 'Orta aylıq xərc: $amount';
  }

  @override
  String get balanceTrend => 'Balansın dinamikası';

  @override
  String get balanceTrendHint =>
      'Ay sonuna ümumi balans (gəlir və xərclər əsasında, AZN).';

  @override
  String get exchangeRates => 'Valyuta məzənnələri';

  @override
  String get exchangeRatesSubtitle => 'USD, EUR, RUB, TRY → AZN';

  @override
  String get exchangeRatesHint =>
      '1 vahid xarici valyutanın neçə manat olduğunu daxil edin. Bütün cəmlər bu məzənnələrlə hesablanır.';

  @override
  String rateLabel(String code) {
    return '$code məzənnəsi';
  }

  @override
  String get ratePositive => 'Müsbət ədəd daxil edin (məs. 1,70)';

  @override
  String get ratesSaved => 'Məzənnələr yadda saxlanıldı';

  @override
  String get blockScreenshots => 'Ekran görüntüsünü qadağan et';

  @override
  String get blockScreenshotsSubtitle =>
      'Ekran şəkli və son tətbiqlərdə önizləmə bağlanır';

  @override
  String get export => 'İxrac';

  @override
  String get exportSubtitle => 'CSV, Excel və ya PDF';

  @override
  String get exportFormat => 'Format';

  @override
  String get exportPeriod => 'Dövr';

  @override
  String get exportAction => 'İxrac et və paylaş';

  @override
  String get exportHint =>
      'Fayl müvəqqəti qovluqda yaradılır və paylaşma pəncərəsi açılır.';

  @override
  String get exportNothing => 'Seçilmiş dövrdə əməliyyat yoxdur';

  @override
  String get exportFailed => 'İxrac alınmadı';

  @override
  String get exportShareTitle => 'Hesabatı paylaş';

  @override
  String get exportPdfTitle => 'Gəlir-Çıxar hesabatı';

  @override
  String get exportGenerated => 'Yaradılıb';

  @override
  String get exportColDate => 'Tarix';

  @override
  String get exportColType => 'Növ';

  @override
  String get exportColAmount => 'Məbləğ';

  @override
  String get exportColAmountAzn => 'Məbləğ (AZN)';

  @override
  String get exportColToAmount => 'Alınan məbləğ';

  @override
  String get backupCreate => 'Ehtiyat nüsxə yarat';

  @override
  String get backupCreateSubtitle => 'Bütün məlumatlar JSON faylına';

  @override
  String get backupShareSubject => 'Gəlir-Çıxar ehtiyat nüsxəsi';

  @override
  String get backupFailed => 'Ehtiyat nüsxə yaradılmadı';

  @override
  String get backupRestore => 'Ehtiyat nüsxədən bərpa et';

  @override
  String get backupRestoreSubtitle => 'Cari məlumatlar əvəz olunacaq';

  @override
  String get backupRestoreConfirmTitle => 'Məlumatlar əvəz olunsun?';

  @override
  String backupRestoreConfirmBody(String file) {
    return 'Bütün cari hesablar, kateqoriyalar, əməliyyatlar və büdcələr \"$file\" faylındakı məlumatlarla əvəz olunacaq. Bunu geri qaytarmaq olmaz.';
  }

  @override
  String get backupRestoreConfirmAction => 'Bərpa et';

  @override
  String backupRestored(int transactions, int accounts) {
    return 'Bərpa olundu: $transactions əməliyyat, $accounts hesab';
  }

  @override
  String get backupReadFailed => 'Fayl oxunmadı';

  @override
  String get backupInvalidFile => 'Bu fayl Gəlir-Çıxar ehtiyat nüsxəsi deyil';

  @override
  String get backupNewerVersion =>
      'Ehtiyat nüsxə tətbiqin daha yeni versiyası ilə yaradılıb. Tətbiqi yeniləyin.';

  @override
  String get backupInvalidData =>
      'Ehtiyat nüsxədəki məlumatlar zədəlidir. Heç nə dəyişdirilmədi.';

  @override
  String get backupTooLarge =>
      'Fayl çox böyükdür (maksimum 32 MB). Heç nə dəyişdirilmədi.';

  @override
  String get txTypeToHolding => 'Kənar yerə';

  @override
  String get txTypeFromHolding => 'Kənar yerdən';

  @override
  String get edit => 'Redaktə et';

  @override
  String get notSet => 'Təyin edilməyib';

  @override
  String get holdings => 'Kənar yerlər';

  @override
  String get holdingsSubtitle =>
      'Evdə, borcda, depozitdə, qızılda saxlanan pul';

  @override
  String get holdingsTotal => 'Kənarda';

  @override
  String get holdingsElsewhere => 'Kənarda';

  @override
  String get netWorth => 'Ümumi sərvət';

  @override
  String get addHolding => 'Kənar yer əlavə et';

  @override
  String get editHolding => 'Kənar yeri redaktə et';

  @override
  String get holdingNotFound => 'Kənar yer tapılmadı';

  @override
  String get holdingOpen => 'Kənar yeri aç';

  @override
  String get emptyHoldingsTitle => 'Kənar yer yoxdur';

  @override
  String get emptyHoldingsBody =>
      'Evdəki nağd pulu, yaxınınızdakı pulu, əmanəti və qızılı burada izləyin. Xərclənə bilən balansa daxil olmur, ümumi sərvətə daxildir.';

  @override
  String get holdingPlace => 'Yer';

  @override
  String get holdingPlaceHomeCash => 'Evdə nağd';

  @override
  String get holdingPlacePerson => 'Yaxın adamda';

  @override
  String get holdingPlaceBankDeposit => 'Bank əmanəti';

  @override
  String get holdingPlaceGold => 'Qızıl, qiymətli əşya';

  @override
  String get holdingPlaceOther => 'Digər';

  @override
  String get holdingNameHint => 'Məs: Sandıq';

  @override
  String get holdingInitialAmount => 'Hazırkı məbləğ';

  @override
  String get holdingCurrencyLocked =>
      'Tarixçəsi olan kənar yerin valyutası dəyişdirilə bilməz.';

  @override
  String get holdingInterestRate => 'İllik faiz';

  @override
  String get holdingInterestInvalid => '0 ilə 100 arasında faiz daxil edin';

  @override
  String holdingInterestValue(String rate) {
    return 'İllik $rate%';
  }

  @override
  String get holdingMaturityDate => 'Bitmə tarixi';

  @override
  String holdingMaturityValue(String date) {
    return 'Bitmə: $date';
  }

  @override
  String get holdingAdjust => 'Məbləği dəyiş';

  @override
  String get holdingEntryAdd => 'Əlavə et';

  @override
  String get holdingEntryWithdraw => 'Götür';

  @override
  String get holdingEntrySetValue => 'Dəyəri yenilə';

  @override
  String get holdingNewValue => 'Yeni dəyər';

  @override
  String get holdingEntryFromAccount => 'hesabdan köçürmə';

  @override
  String get holdingErrorNegative =>
      'Bu dəyişiklik məbləği sıfırdan aşağı salar';

  @override
  String get holdingHistory => 'Tarixçə';

  @override
  String get holdingNoEntries => 'Hələ qeyd yoxdur';

  @override
  String get holdingMove => 'Hesabla köçür';

  @override
  String get holdingMoveIn => 'Hesabdan bura';

  @override
  String get holdingMoveOut => 'Buradan hesaba';

  @override
  String holdingMoveAccountAmount(String code) {
    return 'Hesabda məbləğ ($code)';
  }

  @override
  String holdingMoveHoldingAmount(String code) {
    return 'Kənar yerdə məbləğ ($code)';
  }

  @override
  String get holdingMoveHint =>
      'Köçürmə gəlir və ya xərc sayılmır, büdcələrə təsir etmir.';

  @override
  String get holdingMoveEditElsewhere =>
      'Bu köçürmə Kənar yerlər bölməsindən idarə olunur';

  @override
  String get deleteHoldingTitle => 'Kənar yer silinsin?';

  @override
  String get deleteHoldingBody =>
      'Kənar yer və bütün tarixçəsi birdəfəlik silinəcək.';

  @override
  String get deleteHoldingUsedBody =>
      'Bu kənar yerə hesablardan köçürmələr var, ona görə silinmir, arxivlənəcək.';

  @override
  String get holdingDeleted => 'Kənar yer silindi';

  @override
  String get holdingArchived => 'Kənar yer arxivləndi';

  @override
  String get deleteHoldingEntryTitle => 'Qeyd silinsin?';

  @override
  String get deleteHoldingEntryLinkedBody =>
      'Bu qeyd hesabdan köçürmə ilə yaradılıb. Hesabdakı əməliyyat da silinəcək.';

  @override
  String get exportHoldingsSection => 'Kənar yerlər (cari vəziyyət)';

  @override
  String get autoRates => 'Avtomatik məzənnə (AMB)';

  @override
  String get autoRatesSubtitle =>
      'Mərkəzi Bankın rəsmi məzənnələri, gündə ən çox 2 dəfə';

  @override
  String get ratesRefresh => 'Yenilə';

  @override
  String get ratesRefreshed => 'Məzənnələr yeniləndi';

  @override
  String get ratesNeverUpdated => 'Hələ yenilənməyib';

  @override
  String ratesLastUpdated(String when) {
    return 'Yeniləndi: $when';
  }

  @override
  String ratesBulletinDate(String date) {
    return 'AMB tarixi: $date';
  }

  @override
  String get ratesErrorOffline =>
      'İnternet bağlantısı yoxdur. Sonra yenidən cəhd edin.';

  @override
  String get ratesErrorServer => 'AMB serveri cavab vermədi';

  @override
  String get ratesErrorParse =>
      'AMB məlumatı oxunmadı və ya şübhəlidir. Köhnə məzənnələr saxlanıldı.';

  @override
  String get ratesPrivacyNote =>
      'Yalnız cbar.az saytından ictimai məzənnə faylı yüklənir. Heç bir şəxsi məlumat göndərilmir.';

  @override
  String get rateSourceCbar => 'AMB';

  @override
  String get rateSourceManual => 'Əl ilə';

  @override
  String get rateSourceDefault => 'Standart';

  @override
  String rateAutoValue(String value) {
    return 'AMB: $value';
  }

  @override
  String get rateResetToAuto => 'Avtomatik dəyərə qaytar';

  @override
  String get greetingMorning => 'Sabahınız xeyir';

  @override
  String get greetingAfternoon => 'Günortanız xeyir';

  @override
  String get greetingEvening => 'Axşamınız xeyir';

  @override
  String get greetingNight => 'Salam';

  @override
  String get spendableBalance => 'Xərclənə bilən balans';

  @override
  String get thisWeek => 'Bu həftə';

  @override
  String vsLastWeekLess(int percent) {
    return 'Keçən həftədən $percent% az';
  }

  @override
  String vsLastWeekMore(int percent) {
    return 'Keçən həftədən $percent% çox';
  }

  @override
  String get createBudget => 'Büdcə yarat';

  @override
  String depositEndsIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Əmanətin müddəti $days gün sonra bitir',
      zero: 'Əmanətin müddəti bu gün bitir',
    );
    return '$_temp0';
  }

  @override
  String get depositMatured => 'Müddəti bitib';

  @override
  String daysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days gün qalıb',
      zero: 'bu gün bitir',
    );
    return '$_temp0';
  }

  @override
  String ratesUpdatedAt(String time) {
    return 'Məzənnələr yeniləndi · $time';
  }

  @override
  String ratesOfflineUsingLast(String date) {
    return 'Oflayn: son məzənnələr istifadə olunur ($date)';
  }

  @override
  String get onboardingSkip => 'Keç';

  @override
  String get onboardingNext => 'Davam et';

  @override
  String get onboardingStart => 'Başla';

  @override
  String onboardingPageOf(int page, int total) {
    return 'Səhifə $page / $total';
  }

  @override
  String get onb1Title => 'Gəlir və xərcini bir yerdə gör';

  @override
  String get onb1Body =>
      'Hər əməliyyatı saniyələr içində qeyd et. İnternet lazım deyil.';

  @override
  String get onb2Title => 'Büdcə qur, limitdən xəbərdar ol';

  @override
  String get onb2Body => 'Limitin 80%-nə çatanda xəbərdarlıq edirik.';

  @override
  String get onb3Title => 'Bütün sərvətini izlə';

  @override
  String get onb3Body =>
      'Evdəki nağd pul, əmanət, qızıl: hamısı «Ümumi sərvət»də.';

  @override
  String get chooseLanguage => 'Tətbiqin dili';

  @override
  String get baseCurrencyAzn => 'Əsas valyuta: Azərbaycan manatı';

  @override
  String get aznName => 'Azərbaycan manatı';

  @override
  String get baseCurrencyBody =>
      'Bütün cəmlər AZN-də göstərilir. USD/EUR hesablar məzənnə ilə çevrilir.';

  @override
  String get protectWithPin => 'Tətbiqi PIN ilə qoru';

  @override
  String get protectWithPinBody =>
      'Telefonunuz başqasının əlinə keçsə belə maliyyə məlumatlarınız gizli qalır.';

  @override
  String get setPin => 'PIN qur';

  @override
  String get later => 'Sonra';

  @override
  String get pinIsSet => 'PIN quruldu';

  @override
  String get autoRatesOnboardingTitle => 'Məzənnələri avtomatik yenilə';

  @override
  String get appearance => 'Görünüş';

  @override
  String get themeColour => 'Rəng seçin';

  @override
  String get wallpaperColour => 'Divar kağızı rəngləri';

  @override
  String get wallpaperColourBody => 'Android 12+ divar kağızından rəng götürür';

  @override
  String get wallpaperColourActive => 'Divar kağızı rəngi aktivdir';

  @override
  String get preview => 'Önizləmə';

  @override
  String seedSelected(String name) {
    return '$name, seçilib';
  }

  @override
  String get settingsNotifications => 'Bildirişlər';

  @override
  String get ratesSection => 'Məzənnələr';

  @override
  String get autoRatesShort => 'Avtomatik yenilə';

  @override
  String get autoRatesSource => 'Mənbə: AMB (cbar.az)';

  @override
  String get ratesUpdating => 'Yenilənir…';

  @override
  String get ratesUpdatingShort => 'Yenilənir';

  @override
  String ratesLastUpdatedShort(String when) {
    return 'Son yenilənmə: $when';
  }

  @override
  String get ratesStaleSuffix => '(köhnəlib)';

  @override
  String ratesOfflineSince(String when) {
    return 'Oflayn. Son məzənnələr: $when';
  }

  @override
  String get ratesNotUpdated => 'Yenilənmədi';

  @override
  String ratesNotUpdatedSince(String date) {
    return 'Yenilənmədi. Son məzənnələr: $date';
  }

  @override
  String get ratesNeverFetchedOffline =>
      'Hələ yüklənməyib. Əl ilə daxil edilən məzənnələr istifadə olunur.';

  @override
  String get retry => 'Yenidən cəhd et';

  @override
  String get ratesUnitHeader => '1 vahid = ? AZN';

  @override
  String get manualOverrideNote =>
      'Əl ilə daxil edilən məzənnə avtomatik yenilənmədə dəyişmir.';

  @override
  String get resetToCbar => 'AMB məzənnəsinə qaytar';

  @override
  String holdingsShareOfNetWorth(int percent) {
    return 'Ümumi sərvətin $percent%-i';
  }

  @override
  String holdingsPlaceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count yer',
      one: '1 yer',
    );
    return '$_temp0';
  }

  @override
  String holdingsZeroGroup(int count) {
    return 'Sıfır qalıqlılar ($count)';
  }

  @override
  String get updatedToday => 'bu gün yeniləndi';

  @override
  String updatedDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days gün əvvəl yeniləndi',
      one: '1 gün əvvəl yeniləndi',
    );
    return '$_temp0';
  }

  @override
  String holdingDeleteConfirm(String name) {
    return '«$name» silinsin?';
  }

  @override
  String holdingCurrentAmount(String amount) {
    return 'indiki $amount';
  }

  @override
  String holdingNewBalance(String amount) {
    return 'Yeni qalıq: $amount';
  }

  @override
  String holdingDifference(String amount) {
    return 'Fərq: $amount';
  }

  @override
  String get withdrawTooMuch => 'Qalıqdan çox götürmək olmaz';

  @override
  String get linkFromAccount => 'Hesabdan köçür';

  @override
  String get linkToAccount => 'Hesaba köçür';

  @override
  String get holdingUpdateValue => 'Dəyəri yenilə';

  @override
  String get holdingValueShort => 'Dəyər';

  @override
  String get estimatedInterest => 'Təxmini gəlir';

  @override
  String get range3m => '3A';

  @override
  String get range6m => '6A';

  @override
  String get range1y => '1İ';

  @override
  String get chartNeedsTwoPoints => 'Qrafik üçün ən azı 2 qeyd lazımdır';

  @override
  String get holdingAdded => 'Əlavə edildi';

  @override
  String get holdingWithdrawn => 'Götürüldü';

  @override
  String get holdingValueSet => 'Dəyər yeniləndi';

  @override
  String holdingBefore(String amount) {
    return 'əvvəl $amount';
  }

  @override
  String fromAccountName(String name) {
    return '$name hesabından';
  }

  @override
  String toAccountName(String name) {
    return '$name hesabına';
  }

  @override
  String get holdingNameHintPerson => 'Məs: Anamda';

  @override
  String get holdingNameHintDeposit => 'Məs: Kapital 12 ay';

  @override
  String get holdingNameHintGold => 'Məs: Qızıl üzük';

  @override
  String get holdingFromAccount => 'Məbləği hesabdan köçür';

  @override
  String get holdingCurrencyLockedHelper =>
      'Tarixçə olduğu üçün valyuta dəyişmir';

  @override
  String get maturityAfterToday => 'Bitmə tarixi bu gündən sonra olmalıdır';

  @override
  String get holdingMoveChip => 'Kənar yer';

  @override
  String get rateJumpTitle => 'Məzənnə kəskin dəyişib';

  @override
  String get rateJumpBody =>
      'AMB-dən gələn bu məzənnələr əvvəlkindən 50%-dən çox fərqlənir. Tətbiq edilsin?';

  @override
  String get rateJumpKeep => 'Köhnəni saxla';

  @override
  String get rateJumpApply => 'Tətbiq et';

  @override
  String get lockTimeoutTitle => 'Avtomatik kilid';

  @override
  String get lockTimeoutHint =>
      'Tətbiq arxa fonda bu qədər qaldıqdan sonra PIN tələb olunur.';

  @override
  String get lockTimeoutImmediately => 'Dərhal';

  @override
  String lockTimeoutSeconds(int seconds) {
    return '$seconds saniyə sonra';
  }

  @override
  String lockTimeoutMinutes(int minutes) {
    return '$minutes dəqiqə sonra';
  }

  @override
  String lockTimeoutHours(int hours) {
    return '$hours saat sonra';
  }

  @override
  String get lockTimeoutReauthReason =>
      'Avtomatik kilid vaxtını dəyişmək üçün təsdiqləyin';

  @override
  String get lockBiometricEnrollmentChanged =>
      'Telefona yeni barmaq izi əlavə edilib. Təhlükəsizlik üçün PIN daxil edin.';

  @override
  String get lockRecoveryTitle => 'PIN məlumatı itib';

  @override
  String get lockRecoveryBody =>
      'Telefonun təhlükəsiz yaddaşı sıfırlandığı üçün tətbiqin PIN kodu silinib. Məlumatlarınız yerindədir. Davam etmək üçün telefonun öz kilidi (PIN, naxış və ya barmaq izi) ilə təsdiqləyin, sonra yeni PIN təyin edin.';

  @override
  String get lockRecoveryConfirmButton => 'Telefon kilidi ilə təsdiqlə';

  @override
  String get lockRecoveryReason =>
      'Gəlir-Çıxar-a girişi bərpa etmək üçün təsdiqləyin';

  @override
  String get lockRecoveryAuthFailed => 'Təsdiq alınmadı. Yenidən cəhd edin.';

  @override
  String get lockRecoveryInsecureBody =>
      'Bu telefonda ekran kilidi (PIN, naxış və ya parol) qurulmayıb, ona görə də kimliyinizi telefon vasitəsilə təsdiqləmək mümkün deyil. Yeni PIN təyin etməklə girişi bərpa edə bilərsiniz.';

  @override
  String get lockRecoveryRestoreButton => 'Məlumatlarıma girişi bərpa et';

  @override
  String get lockRecoveryWarningTitle => 'Diqqət';

  @override
  String get lockRecoveryWarningBody =>
      'Telefonu əlində tutan hər kəs bu addımla yeni PIN təyin edib məlumatlarınızı görə bilər. Bunu yalnız telefon sizindirsə edin. Telefonda ekran kilidi qurmağınız tövsiyə olunur.';

  @override
  String get lockRecoveryWarningConfirm => 'Bərpa et';

  @override
  String get thisMonthShort => 'Bu ay';

  @override
  String cardPosition(int n, int total) {
    return 'Kart $n / $total';
  }

  @override
  String cardEndingIn(String last4) {
    return 'kart sonu $last4';
  }

  @override
  String bonusBadge(int pct) {
    return 'Bonus $pct%';
  }

  @override
  String get negativeShort => 'Mənfi';

  @override
  String get cardDesign => 'Kart dizaynı';

  @override
  String get cardChangeDesign => 'Kart dizaynını dəyiş';

  @override
  String get cardDesignPhoto => 'Şəkil';

  @override
  String get cardChoosePhoto => 'Şəkil seç';

  @override
  String get cardChangePhoto => 'Şəkli dəyiş';

  @override
  String get cardRemovePhoto => 'Şəkli sil';

  @override
  String get cardPhotoMissing => 'Şəkil tapılmadı';

  @override
  String get cardPhotoFailed => 'Şəkli açmaq mümkün olmadı';

  @override
  String get cardLast4Label => 'Kartın son 4 rəqəmi';

  @override
  String get cardLast4Helper =>
      'Yalnız son 4 rəqəm. Tam kart nömrəsini heç vaxt daxil etməyin.';

  @override
  String get cardLast4Invalid => 'Düz 4 rəqəm daxil edin';

  @override
  String selectedItem(String name) {
    return '$name, seçilib';
  }

  @override
  String get accountTypeBonus => 'Bonus';

  @override
  String get bonusRate => 'Köçürmə dərəcəsi (%)';

  @override
  String get bonusRateHelper => 'Bonusdan başqa hesaba köçürəndə çatan faiz';

  @override
  String get bonusRateInvalid => '1 ilə 100 arasında tam ədəd';

  @override
  String get makeTransfer => 'Köçürmə et';

  @override
  String get time => 'Saat';

  @override
  String addedAt(String dt) {
    return 'Əlavə edilib: $dt';
  }

  @override
  String editedAt(String dt) {
    return 'Dəyişdirilib: $dt';
  }

  @override
  String get duplicate => 'Təkrarla';

  @override
  String get transportMode => 'Növ';

  @override
  String get transportBus => 'Avtobus';

  @override
  String get transportMetro => 'Metro';

  @override
  String get transportTaxi => 'Taksi';

  @override
  String get transportTrain => 'Elektrik qatarı';

  @override
  String get transportFuel => 'Yanacaq';

  @override
  String get transportParking => 'Parkinq';

  @override
  String get transportBakuCard => 'BakıKart artırma';

  @override
  String get busRoute => 'Marşrut';

  @override
  String get chooseRoute => 'Marşrut seçin';

  @override
  String get searchRoutes => 'Marşrut axtar: kod və ya dayanacaq';

  @override
  String get recentRoutes => 'Son istifadə olunanlar';

  @override
  String get allRoutes => 'Bütün marşrutlar';

  @override
  String get noRouteFound => 'Marşrut tapılmadı';

  @override
  String get trips => 'Gediş sayı';

  @override
  String tripsCount(int n) {
    return '$n gediş';
  }

  @override
  String fareHint(String fare, int n) {
    return 'Tarif: $fare × $n';
  }

  @override
  String get fareManual => 'Məbləğ əl ilə dəyişdirilib';

  @override
  String get resetToFare => 'Tarifə qaytar';

  @override
  String get fareUncertain => 'tarif dəqiq deyil';

  @override
  String get metroStation => 'Stansiya (istəyə görə)';

  @override
  String get chooseStation => 'Stansiya seçin';

  @override
  String get bakuCardDoubleCountHint =>
      'Artırmanı xərc kimi qeyd edirsinizsə, gedişləri ayrıca qeyd etməyin: xərc iki dəfə sayılar.';

  @override
  String get transportFares => 'Nəqliyyat tarifləri';

  @override
  String get transportFaresSubtitle => 'Avtobus, metro və qatar tarifləri';

  @override
  String get addOwnRoute => 'Öz marşrutumu əlavə et';

  @override
  String get editOwnRoute => 'Marşrutu dəyiş';

  @override
  String get routeCode => 'Marşrut nömrəsi';

  @override
  String get routeFrom => 'Haradan';

  @override
  String get routeTo => 'Haraya';

  @override
  String get fare => 'Tarif';

  @override
  String get routeCodeExists => 'Bu nömrə artıq var';

  @override
  String get routeCodeInvalid => '1–6 simvol: hərf, rəqəm və ya \"-\"';

  @override
  String get fieldRequired => 'Doldurun';

  @override
  String get fareInvalid => '0,01 ilə 99,99 arasında';

  @override
  String get fareNotSet => 'Təyin edilməyib';

  @override
  String get myRoute => 'Mənim';

  @override
  String get fareEdited => 'Dəyişdirilib';

  @override
  String get resetFare => 'Standart tarifə qaytar';

  @override
  String faresVerifiedAt(String date) {
    return 'Tariflər $date tarixində yoxlanılıb. Dəyişibsə, burada düzəldin.';
  }

  @override
  String faresVerifiedShort(String date) {
    return 'Yoxlanılıb: $date';
  }

  @override
  String get faresSources => 'Mənbələr';

  @override
  String get metroAndTrain => 'Metro və qatar';

  @override
  String transferSent(String a) {
    return 'Göndərilən $a';
  }

  @override
  String transferArrives(String a, int pct) {
    return 'Çatan $a ($pct%)';
  }

  @override
  String bonusLoss(String a) {
    return 'Bonus itkisi: $a';
  }

  @override
  String get bonusLossLabel => 'Bonus itkisi';

  @override
  String bonusLossExplain(int pct) {
    return 'Bonus hesabından köçürəndə məbləğin yalnız $pct%-i çatır.';
  }

  @override
  String get bonusReceivedEdit => 'Çatan məbləğ';

  @override
  String get bonusReceivedTooBig => 'Çatan məbləğ göndəriləndən çox ola bilməz';

  @override
  String get bonusSameCurrencyOnly =>
      'Bonus hesabından yalnız eyni valyutada olan hesaba köçürmək olar';

  @override
  String sentSubtitle(String a) {
    return '$a göndərildi';
  }

  @override
  String get pairDeleted => 'Köçürmə və bonus itkisi birlikdə silindi';

  @override
  String get systemCategoryLocked =>
      'Sistem kateqoriyasıdır: silmək və arxivləmək olmaz';

  @override
  String get transportCategory => 'Nəqliyyat kateqoriyası';

  @override
  String get transportCategoryBody =>
      'Əlavə edəndə avtobus, metro və digər növləri seçmək olar';

  @override
  String get budgetsEnabled => 'Büdcələr';

  @override
  String get budgetsEnabledBody =>
      'Büdcə bölməsini, Ana səhifə kartını və xəbərdarlıqları göstər';

  @override
  String get budgetsHidden => 'Büdcələr gizlədildi. Məlumatlarınız silinmir.';

  @override
  String get pressBackAgainToExit => 'Çıxmaq üçün yenidən geri toxunun';

  @override
  String get reportTransport => 'Nəqliyyat';

  @override
  String get reportByMode => 'Növlər üzrə';

  @override
  String get reportTopRoutes => 'Ən çox istifadə olunan marşrutlar';

  @override
  String get timeOfDay => 'Saat aralığı';

  @override
  String get timeFrom => 'Başlanğıc saatı';

  @override
  String get timeTo => 'Son saat';

  @override
  String backupImagesSkipped(int n) {
    return '$n kart şəkli 1 MB-dan böyük olduğu üçün ehtiyat nüsxəyə düşmədi';
  }

  @override
  String accountCardSemantics(String type, String name, String balance) {
    return '$type, $name, $balance';
  }

  @override
  String get exportColTransportMode => 'Nəqliyyat növü';
}
