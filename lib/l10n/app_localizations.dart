import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_az.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('az'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In az, this message translates to:
  /// **'Gəlir-Çıxar'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In az, this message translates to:
  /// **'Ana səhifə'**
  String get navHome;

  /// No description provided for @navTransactions.
  ///
  /// In az, this message translates to:
  /// **'Əməliyyatlar'**
  String get navTransactions;

  /// No description provided for @navReports.
  ///
  /// In az, this message translates to:
  /// **'Hesabatlar'**
  String get navReports;

  /// No description provided for @navBudgets.
  ///
  /// In az, this message translates to:
  /// **'Büdcələr'**
  String get navBudgets;

  /// No description provided for @navSettings.
  ///
  /// In az, this message translates to:
  /// **'Ayarlar'**
  String get navSettings;

  /// No description provided for @genericError.
  ///
  /// In az, this message translates to:
  /// **'Xəta baş verdi'**
  String get genericError;

  /// No description provided for @cancel.
  ///
  /// In az, this message translates to:
  /// **'Ləğv et'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In az, this message translates to:
  /// **'Saxla'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In az, this message translates to:
  /// **'Sil'**
  String get delete;

  /// No description provided for @close.
  ///
  /// In az, this message translates to:
  /// **'Bağla'**
  String get close;

  /// No description provided for @confirm.
  ///
  /// In az, this message translates to:
  /// **'Təsdiqlə'**
  String get confirm;

  /// No description provided for @clear.
  ///
  /// In az, this message translates to:
  /// **'Təmizlə'**
  String get clear;

  /// No description provided for @more.
  ///
  /// In az, this message translates to:
  /// **'Daha çox'**
  String get more;

  /// No description provided for @undo.
  ///
  /// In az, this message translates to:
  /// **'Geri al'**
  String get undo;

  /// No description provided for @all.
  ///
  /// In az, this message translates to:
  /// **'Hamısı'**
  String get all;

  /// No description provided for @seeAll.
  ///
  /// In az, this message translates to:
  /// **'Hamısı'**
  String get seeAll;

  /// No description provided for @total.
  ///
  /// In az, this message translates to:
  /// **'Ümumi'**
  String get total;

  /// No description provided for @today.
  ///
  /// In az, this message translates to:
  /// **'Bu gün'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In az, this message translates to:
  /// **'Dünən'**
  String get yesterday;

  /// No description provided for @income.
  ///
  /// In az, this message translates to:
  /// **'Gəlir'**
  String get income;

  /// No description provided for @expense.
  ///
  /// In az, this message translates to:
  /// **'Xərc'**
  String get expense;

  /// No description provided for @net.
  ///
  /// In az, this message translates to:
  /// **'Net'**
  String get net;

  /// No description provided for @txTypeIncome.
  ///
  /// In az, this message translates to:
  /// **'Gəlir'**
  String get txTypeIncome;

  /// No description provided for @txTypeExpense.
  ///
  /// In az, this message translates to:
  /// **'Xərc'**
  String get txTypeExpense;

  /// No description provided for @txTypeTransfer.
  ///
  /// In az, this message translates to:
  /// **'Transfer'**
  String get txTypeTransfer;

  /// No description provided for @uncategorized.
  ///
  /// In az, this message translates to:
  /// **'Kateqoriyasız'**
  String get uncategorized;

  /// No description provided for @totalBalance.
  ///
  /// In az, this message translates to:
  /// **'Ümumi balans'**
  String get totalBalance;

  /// No description provided for @showBalance.
  ///
  /// In az, this message translates to:
  /// **'Balansı göstər'**
  String get showBalance;

  /// No description provided for @hideBalance.
  ///
  /// In az, this message translates to:
  /// **'Balansı gizlət'**
  String get hideBalance;

  /// No description provided for @balanceHidden.
  ///
  /// In az, this message translates to:
  /// **'Balans gizlədilib'**
  String get balanceHidden;

  /// No description provided for @negativeBalance.
  ///
  /// In az, this message translates to:
  /// **'Mənfi balans'**
  String get negativeBalance;

  /// No description provided for @thisMonth.
  ///
  /// In az, this message translates to:
  /// **'Bu ay: {month}'**
  String thisMonth(String month);

  /// No description provided for @recentTransactions.
  ///
  /// In az, this message translates to:
  /// **'Son əməliyyatlar'**
  String get recentTransactions;

  /// No description provided for @accounts.
  ///
  /// In az, this message translates to:
  /// **'Hesablar'**
  String get accounts;

  /// No description provided for @account.
  ///
  /// In az, this message translates to:
  /// **'Hesab'**
  String get account;

  /// No description provided for @addAccount.
  ///
  /// In az, this message translates to:
  /// **'Hesab əlavə et'**
  String get addAccount;

  /// No description provided for @newAccount.
  ///
  /// In az, this message translates to:
  /// **'Yeni hesab'**
  String get newAccount;

  /// No description provided for @editAccount.
  ///
  /// In az, this message translates to:
  /// **'Hesabı redaktə et'**
  String get editAccount;

  /// No description provided for @accountNotFound.
  ///
  /// In az, this message translates to:
  /// **'Hesab tapılmadı'**
  String get accountNotFound;

  /// No description provided for @accountType.
  ///
  /// In az, this message translates to:
  /// **'Hesabın növü'**
  String get accountType;

  /// No description provided for @accountTypeCash.
  ///
  /// In az, this message translates to:
  /// **'Nağd'**
  String get accountTypeCash;

  /// No description provided for @accountTypeCard.
  ///
  /// In az, this message translates to:
  /// **'Kart'**
  String get accountTypeCard;

  /// No description provided for @accountTypeBank.
  ///
  /// In az, this message translates to:
  /// **'Bank hesabı'**
  String get accountTypeBank;

  /// No description provided for @accountTypeSavings.
  ///
  /// In az, this message translates to:
  /// **'Əmanət'**
  String get accountTypeSavings;

  /// No description provided for @currency.
  ///
  /// In az, this message translates to:
  /// **'Valyuta'**
  String get currency;

  /// No description provided for @currencyLockedHint.
  ///
  /// In az, this message translates to:
  /// **'Əməliyyatı olan hesabın valyutası dəyişdirilə bilməz.'**
  String get currencyLockedHint;

  /// No description provided for @initialBalance.
  ///
  /// In az, this message translates to:
  /// **'Başlanğıc balans'**
  String get initialBalance;

  /// No description provided for @color.
  ///
  /// In az, this message translates to:
  /// **'Rəng'**
  String get color;

  /// No description provided for @colorN.
  ///
  /// In az, this message translates to:
  /// **'Rəng {n}'**
  String colorN(int n);

  /// No description provided for @name.
  ///
  /// In az, this message translates to:
  /// **'Ad'**
  String get name;

  /// No description provided for @nameRequired.
  ///
  /// In az, this message translates to:
  /// **'Ad daxil edin'**
  String get nameRequired;

  /// No description provided for @archive.
  ///
  /// In az, this message translates to:
  /// **'Arxivlə'**
  String get archive;

  /// No description provided for @unarchive.
  ///
  /// In az, this message translates to:
  /// **'Arxivdən çıxar'**
  String get unarchive;

  /// No description provided for @archived.
  ///
  /// In az, this message translates to:
  /// **'arxivdə'**
  String get archived;

  /// No description provided for @archivedCount.
  ///
  /// In az, this message translates to:
  /// **'Arxivlənmiş ({count})'**
  String archivedCount(int count);

  /// No description provided for @deleteAccountTitle.
  ///
  /// In az, this message translates to:
  /// **'Hesab silinsin?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In az, this message translates to:
  /// **'Bu hesab birdəfəlik silinəcək.'**
  String get deleteAccountBody;

  /// No description provided for @deleteAccountUsedBody.
  ///
  /// In az, this message translates to:
  /// **'Bu hesabda əməliyyatlar var, ona görə silinmir, arxivlənəcək. Tarixçə saxlanılır.'**
  String get deleteAccountUsedBody;

  /// No description provided for @accountDeleted.
  ///
  /// In az, this message translates to:
  /// **'Hesab silindi'**
  String get accountDeleted;

  /// No description provided for @accountArchived.
  ///
  /// In az, this message translates to:
  /// **'Hesab arxivləndi'**
  String get accountArchived;

  /// No description provided for @emptyAccountsTitle.
  ///
  /// In az, this message translates to:
  /// **'Hesab əlavə edin'**
  String get emptyAccountsTitle;

  /// No description provided for @categories.
  ///
  /// In az, this message translates to:
  /// **'Kateqoriyalar'**
  String get categories;

  /// No description provided for @category.
  ///
  /// In az, this message translates to:
  /// **'Kateqoriya'**
  String get category;

  /// No description provided for @newCategory.
  ///
  /// In az, this message translates to:
  /// **'Yeni kateqoriya'**
  String get newCategory;

  /// No description provided for @editCategory.
  ///
  /// In az, this message translates to:
  /// **'Kateqoriyanı redaktə et'**
  String get editCategory;

  /// No description provided for @categoryNotFound.
  ///
  /// In az, this message translates to:
  /// **'Kateqoriya tapılmadı'**
  String get categoryNotFound;

  /// No description provided for @nameAz.
  ///
  /// In az, this message translates to:
  /// **'Ad (Azərbaycanca)'**
  String get nameAz;

  /// No description provided for @nameEn.
  ///
  /// In az, this message translates to:
  /// **'Ad (İngiliscə)'**
  String get nameEn;

  /// No description provided for @nameEnHint.
  ///
  /// In az, this message translates to:
  /// **'Boş qalsa, azərbaycanca ad göstərilir'**
  String get nameEnHint;

  /// No description provided for @icon.
  ///
  /// In az, this message translates to:
  /// **'İkon'**
  String get icon;

  /// No description provided for @transactionCount.
  ///
  /// In az, this message translates to:
  /// **'{count, plural, =0{Əməliyyat yoxdur} other{{count} əməliyyat}}'**
  String transactionCount(int count);

  /// No description provided for @deleteCategoryTitle.
  ///
  /// In az, this message translates to:
  /// **'Kateqoriya silinsin?'**
  String get deleteCategoryTitle;

  /// No description provided for @deleteCategoryBody.
  ///
  /// In az, this message translates to:
  /// **'Bu kateqoriya birdəfəlik silinəcək.'**
  String get deleteCategoryBody;

  /// No description provided for @deleteCategoryUsedBody.
  ///
  /// In az, this message translates to:
  /// **'Bu kateqoriya istifadə olunur, ona görə silinmir, arxivlənəcək.'**
  String get deleteCategoryUsedBody;

  /// No description provided for @categoryDeleted.
  ///
  /// In az, this message translates to:
  /// **'Kateqoriya silindi'**
  String get categoryDeleted;

  /// No description provided for @categoryArchived.
  ///
  /// In az, this message translates to:
  /// **'Kateqoriya arxivləndi'**
  String get categoryArchived;

  /// No description provided for @emptyCategoriesTitle.
  ///
  /// In az, this message translates to:
  /// **'Kateqoriya yoxdur'**
  String get emptyCategoriesTitle;

  /// No description provided for @addTransaction.
  ///
  /// In az, this message translates to:
  /// **'Əməliyyat əlavə et'**
  String get addTransaction;

  /// No description provided for @newTransaction.
  ///
  /// In az, this message translates to:
  /// **'Yeni əməliyyat'**
  String get newTransaction;

  /// No description provided for @editTransaction.
  ///
  /// In az, this message translates to:
  /// **'Əməliyyatı redaktə et'**
  String get editTransaction;

  /// No description provided for @transactionNotFound.
  ///
  /// In az, this message translates to:
  /// **'Əməliyyat tapılmadı'**
  String get transactionNotFound;

  /// No description provided for @emptyTransactionsTitle.
  ///
  /// In az, this message translates to:
  /// **'Hələ əməliyyat yoxdur'**
  String get emptyTransactionsTitle;

  /// No description provided for @emptyTransactionsBody.
  ///
  /// In az, this message translates to:
  /// **'İlk gəlir və ya xərcinizi əlavə edin.'**
  String get emptyTransactionsBody;

  /// No description provided for @emptyFilteredTitle.
  ///
  /// In az, this message translates to:
  /// **'Uyğun nəticə tapılmadı'**
  String get emptyFilteredTitle;

  /// No description provided for @resetFilters.
  ///
  /// In az, this message translates to:
  /// **'Filtrləri sıfırla'**
  String get resetFilters;

  /// No description provided for @search.
  ///
  /// In az, this message translates to:
  /// **'Axtar'**
  String get search;

  /// No description provided for @closeSearch.
  ///
  /// In az, this message translates to:
  /// **'Axtarışı bağla'**
  String get closeSearch;

  /// No description provided for @searchNotes.
  ///
  /// In az, this message translates to:
  /// **'Qeydlərdə axtar'**
  String get searchNotes;

  /// No description provided for @allAccounts.
  ///
  /// In az, this message translates to:
  /// **'Bütün hesablar'**
  String get allAccounts;

  /// No description provided for @allCategories.
  ///
  /// In az, this message translates to:
  /// **'Bütün kateqoriyalar'**
  String get allCategories;

  /// No description provided for @dateRange.
  ///
  /// In az, this message translates to:
  /// **'Tarix'**
  String get dateRange;

  /// No description provided for @date.
  ///
  /// In az, this message translates to:
  /// **'Tarix'**
  String get date;

  /// No description provided for @note.
  ///
  /// In az, this message translates to:
  /// **'Qeyd'**
  String get note;

  /// No description provided for @addNote.
  ///
  /// In az, this message translates to:
  /// **'Qeyd əlavə et'**
  String get addNote;

  /// No description provided for @noteHint.
  ///
  /// In az, this message translates to:
  /// **'Məsələn: Bravo market'**
  String get noteHint;

  /// No description provided for @fromAccount.
  ///
  /// In az, this message translates to:
  /// **'Haradan'**
  String get fromAccount;

  /// No description provided for @toAccount.
  ///
  /// In az, this message translates to:
  /// **'Haraya'**
  String get toAccount;

  /// No description provided for @amountSent.
  ///
  /// In az, this message translates to:
  /// **'Göndərilən'**
  String get amountSent;

  /// No description provided for @amountReceived.
  ///
  /// In az, this message translates to:
  /// **'Alınan'**
  String get amountReceived;

  /// No description provided for @transactionDeleted.
  ///
  /// In az, this message translates to:
  /// **'Əməliyyat silindi'**
  String get transactionDeleted;

  /// No description provided for @deleteTransactionTitle.
  ///
  /// In az, this message translates to:
  /// **'Əməliyyat silinsin?'**
  String get deleteTransactionTitle;

  /// No description provided for @deleteTransactionBody.
  ///
  /// In az, this message translates to:
  /// **'Bu əməliyyat silinəcək.'**
  String get deleteTransactionBody;

  /// No description provided for @enterAmount.
  ///
  /// In az, this message translates to:
  /// **'Məbləğ daxil edin'**
  String get enterAmount;

  /// No description provided for @invalidAmount.
  ///
  /// In az, this message translates to:
  /// **'Yanlış məbləğ'**
  String get invalidAmount;

  /// No description provided for @enterReceivedAmount.
  ///
  /// In az, this message translates to:
  /// **'Alınan məbləği daxil edin'**
  String get enterReceivedAmount;

  /// No description provided for @selectAccount.
  ///
  /// In az, this message translates to:
  /// **'Hesab seçin'**
  String get selectAccount;

  /// No description provided for @selectToAccount.
  ///
  /// In az, this message translates to:
  /// **'Hədəf hesabı seçin'**
  String get selectToAccount;

  /// No description provided for @sameAccountError.
  ///
  /// In az, this message translates to:
  /// **'Hesablar fərqli olmalıdır'**
  String get sameAccountError;

  /// No description provided for @selectCategory.
  ///
  /// In az, this message translates to:
  /// **'Kateqoriya seçin'**
  String get selectCategory;

  /// No description provided for @backspace.
  ///
  /// In az, this message translates to:
  /// **'Sil'**
  String get backspace;

  /// No description provided for @backspaceHint.
  ///
  /// In az, this message translates to:
  /// **'Basıb saxlayın: hamısını sil'**
  String get backspaceHint;

  /// No description provided for @plus.
  ///
  /// In az, this message translates to:
  /// **'Üstəgəl'**
  String get plus;

  /// No description provided for @plusHint.
  ///
  /// In az, this message translates to:
  /// **'Basıb saxlayın: vurma (×)'**
  String get plusHint;

  /// No description provided for @minus.
  ///
  /// In az, this message translates to:
  /// **'Çıx'**
  String get minus;

  /// No description provided for @minusHint.
  ///
  /// In az, this message translates to:
  /// **'Basıb saxlayın: bölmə (÷)'**
  String get minusHint;

  /// No description provided for @decimalPoint.
  ///
  /// In az, this message translates to:
  /// **'Onluq ayırıcı'**
  String get decimalPoint;

  /// No description provided for @equals.
  ///
  /// In az, this message translates to:
  /// **'Bərabərdir'**
  String get equals;

  /// No description provided for @enterPin.
  ///
  /// In az, this message translates to:
  /// **'PIN kodu daxil edin'**
  String get enterPin;

  /// No description provided for @enterCurrentPin.
  ///
  /// In az, this message translates to:
  /// **'Hazırkı PIN kodu daxil edin'**
  String get enterCurrentPin;

  /// No description provided for @createPin.
  ///
  /// In az, this message translates to:
  /// **'Yeni PIN kod yaradın'**
  String get createPin;

  /// No description provided for @confirmPin.
  ///
  /// In az, this message translates to:
  /// **'PIN kodu təkrar daxil edin'**
  String get confirmPin;

  /// No description provided for @pinLengthHint.
  ///
  /// In az, this message translates to:
  /// **'4–6 rəqəm, sonra ✓ basın'**
  String get pinLengthHint;

  /// No description provided for @pinMismatch.
  ///
  /// In az, this message translates to:
  /// **'PIN kodlar uyğun gəlmir. Yenidən cəhd edin.'**
  String get pinMismatch;

  /// No description provided for @pinSetupIntro.
  ///
  /// In az, this message translates to:
  /// **'Məlumatlarınızı qorumaq üçün PIN kod təyin edin. Kilidi sonra Ayarlarda söndürə bilərsiniz.'**
  String get pinSetupIntro;

  /// No description provided for @pinDigitsEntered.
  ///
  /// In az, this message translates to:
  /// **'{entered} / {total} rəqəm daxil edilib'**
  String pinDigitsEntered(int entered, int total);

  /// No description provided for @wrongPinAttemptsLeft.
  ///
  /// In az, this message translates to:
  /// **'{count, plural, =0{Yanlış PIN} other{Yanlış PIN. {count} cəhd qalıb}}'**
  String wrongPinAttemptsLeft(int count);

  /// No description provided for @lockedOutFor.
  ///
  /// In az, this message translates to:
  /// **'Çox sayda yanlış cəhd. {seconds} saniyə gözləyin.'**
  String lockedOutFor(int seconds);

  /// No description provided for @useFingerprint.
  ///
  /// In az, this message translates to:
  /// **'Barmaq izi ilə aç'**
  String get useFingerprint;

  /// No description provided for @biometricReason.
  ///
  /// In az, this message translates to:
  /// **'Gəlir-Çıxar-ı açmaq üçün təsdiqləyin'**
  String get biometricReason;

  /// No description provided for @biometricEnableReason.
  ///
  /// In az, this message translates to:
  /// **'Barmaq izi ilə açılışı aktivləşdirmək üçün təsdiqləyin'**
  String get biometricEnableReason;

  /// No description provided for @biometricUnavailable.
  ///
  /// In az, this message translates to:
  /// **'Bu cihazda barmaq izi qeydiyyatda deyil və ya dəstəklənmir'**
  String get biometricUnavailable;

  /// No description provided for @settingsGeneral.
  ///
  /// In az, this message translates to:
  /// **'Ümumi'**
  String get settingsGeneral;

  /// No description provided for @settingsSecurity.
  ///
  /// In az, this message translates to:
  /// **'Təhlükəsizlik'**
  String get settingsSecurity;

  /// No description provided for @settingsData.
  ///
  /// In az, this message translates to:
  /// **'Məlumat'**
  String get settingsData;

  /// No description provided for @settingsAbout.
  ///
  /// In az, this message translates to:
  /// **'Haqqında'**
  String get settingsAbout;

  /// No description provided for @language.
  ///
  /// In az, this message translates to:
  /// **'Dil'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In az, this message translates to:
  /// **'Tema'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In az, this message translates to:
  /// **'Sistem'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In az, this message translates to:
  /// **'Açıq'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In az, this message translates to:
  /// **'Tünd'**
  String get themeDark;

  /// No description provided for @baseCurrency.
  ///
  /// In az, this message translates to:
  /// **'Əsas valyuta'**
  String get baseCurrency;

  /// No description provided for @appLock.
  ///
  /// In az, this message translates to:
  /// **'Tətbiq kilidi'**
  String get appLock;

  /// No description provided for @appLockSubtitle.
  ///
  /// In az, this message translates to:
  /// **'Açılışda PIN kod tələb et'**
  String get appLockSubtitle;

  /// No description provided for @changePin.
  ///
  /// In az, this message translates to:
  /// **'PIN kodu dəyiş'**
  String get changePin;

  /// No description provided for @fingerprint.
  ///
  /// In az, this message translates to:
  /// **'Barmaq izi'**
  String get fingerprint;

  /// No description provided for @fingerprintSubtitle.
  ///
  /// In az, this message translates to:
  /// **'PIN əvəzinə barmaq izi ilə aç'**
  String get fingerprintSubtitle;

  /// No description provided for @about.
  ///
  /// In az, this message translates to:
  /// **'Tətbiq haqqında'**
  String get about;

  /// No description provided for @aboutBody.
  ///
  /// In az, this message translates to:
  /// **'Şəxsi gəlir və xərclərin oflayn izlənməsi. Bütün məlumatlar yalnız bu cihazda saxlanılır.'**
  String get aboutBody;

  /// No description provided for @versionN.
  ///
  /// In az, this message translates to:
  /// **'Versiya {version}'**
  String versionN(String version);

  /// No description provided for @addBudget.
  ///
  /// In az, this message translates to:
  /// **'Büdcə əlavə et'**
  String get addBudget;

  /// No description provided for @editBudget.
  ///
  /// In az, this message translates to:
  /// **'Büdcəni redaktə et'**
  String get editBudget;

  /// No description provided for @deleteBudgetTitle.
  ///
  /// In az, this message translates to:
  /// **'Büdcə silinsin?'**
  String get deleteBudgetTitle;

  /// No description provided for @budgetLimit.
  ///
  /// In az, this message translates to:
  /// **'Aylıq limit'**
  String get budgetLimit;

  /// No description provided for @budgetTotal.
  ///
  /// In az, this message translates to:
  /// **'Ümumi büdcə'**
  String get budgetTotal;

  /// No description provided for @budgetSummary.
  ///
  /// In az, this message translates to:
  /// **'Büdcə xülasəsi'**
  String get budgetSummary;

  /// No description provided for @budgetRemaining.
  ///
  /// In az, this message translates to:
  /// **'Qalıb: {amount}'**
  String budgetRemaining(String amount);

  /// No description provided for @budgetOverBy.
  ///
  /// In az, this message translates to:
  /// **'Aşıb: {amount}'**
  String budgetOverBy(String amount);

  /// No description provided for @budgetStateWarning.
  ///
  /// In az, this message translates to:
  /// **'xəbərdarlıq'**
  String get budgetStateWarning;

  /// No description provided for @budgetStateOver.
  ///
  /// In az, this message translates to:
  /// **'limit aşıldı'**
  String get budgetStateOver;

  /// No description provided for @budgetSemantics.
  ///
  /// In az, this message translates to:
  /// **'{name} büdcəsi, {percent} faiz istifadə olunub'**
  String budgetSemantics(String name, int percent);

  /// No description provided for @budgetDailyAllowance.
  ///
  /// In az, this message translates to:
  /// **'Gündəlik limit: {amount} (qalan {days} gün)'**
  String budgetDailyAllowance(String amount, int days);

  /// No description provided for @budgetsNearLimit.
  ///
  /// In az, this message translates to:
  /// **'{count, plural, =1{1 kateqoriya limitə yaxındır və ya aşıb} other{{count} kateqoriya limitə yaxındır və ya aşıb}}'**
  String budgetsNearLimit(int count);

  /// No description provided for @budgetsCopyLastMonth.
  ///
  /// In az, this message translates to:
  /// **'Keçən ayın büdcələrini köçür'**
  String get budgetsCopyLastMonth;

  /// No description provided for @budgetsCopied.
  ///
  /// In az, this message translates to:
  /// **'{count, plural, =1{1 büdcə köçürüldü} other{{count} büdcə köçürüldü}}'**
  String budgetsCopied(int count);

  /// No description provided for @budgetsCopyNone.
  ///
  /// In az, this message translates to:
  /// **'Köçürüləcək büdcə yoxdur'**
  String get budgetsCopyNone;

  /// No description provided for @budgetAllCategoriesUsed.
  ///
  /// In az, this message translates to:
  /// **'Bütün xərc kateqoriyalarının bu ay üçün büdcəsi var.'**
  String get budgetAllCategoriesUsed;

  /// No description provided for @emptyBudgetsTitle.
  ///
  /// In az, this message translates to:
  /// **'Büdcə qurulmayıb'**
  String get emptyBudgetsTitle;

  /// No description provided for @emptyBudgetsBody.
  ///
  /// In az, this message translates to:
  /// **'Kateqoriyalar üçün aylıq limit təyin edin və xərclərinizi izləyin.'**
  String get emptyBudgetsBody;

  /// No description provided for @positiveAmountRequired.
  ///
  /// In az, this message translates to:
  /// **'Müsbət məbləğ daxil edin'**
  String get positiveAmountRequired;

  /// No description provided for @previousMonth.
  ///
  /// In az, this message translates to:
  /// **'Əvvəlki ay'**
  String get previousMonth;

  /// No description provided for @nextMonth.
  ///
  /// In az, this message translates to:
  /// **'Növbəti ay'**
  String get nextMonth;

  /// No description provided for @budgetAlertWarningTitle.
  ///
  /// In az, this message translates to:
  /// **'{name}: büdcə limitinə yaxınlaşır'**
  String budgetAlertWarningTitle(String name);

  /// No description provided for @budgetAlertWarningBody.
  ///
  /// In az, this message translates to:
  /// **'Limitin {percent}%-i istifadə olunub ({amounts})'**
  String budgetAlertWarningBody(int percent, String amounts);

  /// No description provided for @budgetAlertOverTitle.
  ///
  /// In az, this message translates to:
  /// **'{name}: büdcə limiti aşıldı'**
  String budgetAlertOverTitle(String name);

  /// No description provided for @budgetAlertOverBody.
  ///
  /// In az, this message translates to:
  /// **'Xərclənib: {amounts}'**
  String budgetAlertOverBody(String amounts);

  /// No description provided for @notificationChannelName.
  ///
  /// In az, this message translates to:
  /// **'Büdcə xəbərdarlıqları'**
  String get notificationChannelName;

  /// No description provided for @notificationChannelDescription.
  ///
  /// In az, this message translates to:
  /// **'Büdcə limitinin 80% və 100%-nə çatdıqda'**
  String get notificationChannelDescription;

  /// No description provided for @budgetNotifications.
  ///
  /// In az, this message translates to:
  /// **'Büdcə bildirişləri'**
  String get budgetNotifications;

  /// No description provided for @budgetNotificationsSubtitle.
  ///
  /// In az, this message translates to:
  /// **'Limitin 80% və 100%-ində bildiriş göndər'**
  String get budgetNotificationsSubtitle;

  /// No description provided for @notificationsDenied.
  ///
  /// In az, this message translates to:
  /// **'Bildiriş icazəsi verilmədi. Onu sistem ayarlarından aça bilərsiniz.'**
  String get notificationsDenied;

  /// No description provided for @periodThisMonth.
  ///
  /// In az, this message translates to:
  /// **'Bu ay'**
  String get periodThisMonth;

  /// No description provided for @periodLastMonth.
  ///
  /// In az, this message translates to:
  /// **'Keçən ay'**
  String get periodLastMonth;

  /// No description provided for @periodThisYear.
  ///
  /// In az, this message translates to:
  /// **'Bu il'**
  String get periodThisYear;

  /// No description provided for @periodCustom.
  ///
  /// In az, this message translates to:
  /// **'Xüsusi'**
  String get periodCustom;

  /// No description provided for @emptyReportsTitle.
  ///
  /// In az, this message translates to:
  /// **'Bu dövr üçün məlumat yoxdur'**
  String get emptyReportsTitle;

  /// No description provided for @otherCategories.
  ///
  /// In az, this message translates to:
  /// **'Digər'**
  String get otherCategories;

  /// No description provided for @reportsByMonth.
  ///
  /// In az, this message translates to:
  /// **'Aylar üzrə'**
  String get reportsByMonth;

  /// No description provided for @monthsN.
  ///
  /// In az, this message translates to:
  /// **'{count} ay'**
  String monthsN(int count);

  /// No description provided for @averageMonthlyExpense.
  ///
  /// In az, this message translates to:
  /// **'Orta aylıq xərc: {amount}'**
  String averageMonthlyExpense(String amount);

  /// No description provided for @balanceTrend.
  ///
  /// In az, this message translates to:
  /// **'Balansın dinamikası'**
  String get balanceTrend;

  /// No description provided for @balanceTrendHint.
  ///
  /// In az, this message translates to:
  /// **'Ay sonuna ümumi balans (gəlir və xərclər əsasında, AZN).'**
  String get balanceTrendHint;

  /// No description provided for @exchangeRates.
  ///
  /// In az, this message translates to:
  /// **'Valyuta məzənnələri'**
  String get exchangeRates;

  /// No description provided for @exchangeRatesSubtitle.
  ///
  /// In az, this message translates to:
  /// **'USD, EUR, RUB, TRY → AZN'**
  String get exchangeRatesSubtitle;

  /// No description provided for @exchangeRatesHint.
  ///
  /// In az, this message translates to:
  /// **'1 vahid xarici valyutanın neçə manat olduğunu daxil edin. Bütün cəmlər bu məzənnələrlə hesablanır.'**
  String get exchangeRatesHint;

  /// No description provided for @rateLabel.
  ///
  /// In az, this message translates to:
  /// **'{code} məzənnəsi'**
  String rateLabel(String code);

  /// No description provided for @ratePositive.
  ///
  /// In az, this message translates to:
  /// **'Müsbət ədəd daxil edin (məs. 1,70)'**
  String get ratePositive;

  /// No description provided for @ratesSaved.
  ///
  /// In az, this message translates to:
  /// **'Məzənnələr yadda saxlanıldı'**
  String get ratesSaved;

  /// No description provided for @blockScreenshots.
  ///
  /// In az, this message translates to:
  /// **'Ekran görüntüsünü qadağan et'**
  String get blockScreenshots;

  /// No description provided for @blockScreenshotsSubtitle.
  ///
  /// In az, this message translates to:
  /// **'Ekran şəkli və son tətbiqlərdə önizləmə bağlanır'**
  String get blockScreenshotsSubtitle;

  /// No description provided for @export.
  ///
  /// In az, this message translates to:
  /// **'İxrac'**
  String get export;

  /// No description provided for @exportSubtitle.
  ///
  /// In az, this message translates to:
  /// **'CSV, Excel və ya PDF'**
  String get exportSubtitle;

  /// No description provided for @exportFormat.
  ///
  /// In az, this message translates to:
  /// **'Format'**
  String get exportFormat;

  /// No description provided for @exportPeriod.
  ///
  /// In az, this message translates to:
  /// **'Dövr'**
  String get exportPeriod;

  /// No description provided for @exportAction.
  ///
  /// In az, this message translates to:
  /// **'İxrac et və paylaş'**
  String get exportAction;

  /// No description provided for @exportHint.
  ///
  /// In az, this message translates to:
  /// **'Fayl müvəqqəti qovluqda yaradılır və paylaşma pəncərəsi açılır.'**
  String get exportHint;

  /// No description provided for @exportNothing.
  ///
  /// In az, this message translates to:
  /// **'Seçilmiş dövrdə əməliyyat yoxdur'**
  String get exportNothing;

  /// No description provided for @exportFailed.
  ///
  /// In az, this message translates to:
  /// **'İxrac alınmadı'**
  String get exportFailed;

  /// No description provided for @exportShareTitle.
  ///
  /// In az, this message translates to:
  /// **'Hesabatı paylaş'**
  String get exportShareTitle;

  /// No description provided for @exportPdfTitle.
  ///
  /// In az, this message translates to:
  /// **'Gəlir-Çıxar hesabatı'**
  String get exportPdfTitle;

  /// No description provided for @exportGenerated.
  ///
  /// In az, this message translates to:
  /// **'Yaradılıb'**
  String get exportGenerated;

  /// No description provided for @exportColDate.
  ///
  /// In az, this message translates to:
  /// **'Tarix'**
  String get exportColDate;

  /// No description provided for @exportColType.
  ///
  /// In az, this message translates to:
  /// **'Növ'**
  String get exportColType;

  /// No description provided for @exportColAmount.
  ///
  /// In az, this message translates to:
  /// **'Məbləğ'**
  String get exportColAmount;

  /// No description provided for @exportColAmountAzn.
  ///
  /// In az, this message translates to:
  /// **'Məbləğ (AZN)'**
  String get exportColAmountAzn;

  /// No description provided for @exportColToAmount.
  ///
  /// In az, this message translates to:
  /// **'Alınan məbləğ'**
  String get exportColToAmount;

  /// No description provided for @backupCreate.
  ///
  /// In az, this message translates to:
  /// **'Ehtiyat nüsxə yarat'**
  String get backupCreate;

  /// No description provided for @backupCreateSubtitle.
  ///
  /// In az, this message translates to:
  /// **'Bütün məlumatlar JSON faylına'**
  String get backupCreateSubtitle;

  /// No description provided for @backupShareSubject.
  ///
  /// In az, this message translates to:
  /// **'Gəlir-Çıxar ehtiyat nüsxəsi'**
  String get backupShareSubject;

  /// No description provided for @backupFailed.
  ///
  /// In az, this message translates to:
  /// **'Ehtiyat nüsxə yaradılmadı'**
  String get backupFailed;

  /// No description provided for @backupRestore.
  ///
  /// In az, this message translates to:
  /// **'Ehtiyat nüsxədən bərpa et'**
  String get backupRestore;

  /// No description provided for @backupRestoreSubtitle.
  ///
  /// In az, this message translates to:
  /// **'Cari məlumatlar əvəz olunacaq'**
  String get backupRestoreSubtitle;

  /// No description provided for @backupRestoreConfirmTitle.
  ///
  /// In az, this message translates to:
  /// **'Məlumatlar əvəz olunsun?'**
  String get backupRestoreConfirmTitle;

  /// No description provided for @backupRestoreConfirmBody.
  ///
  /// In az, this message translates to:
  /// **'Bütün cari hesablar, kateqoriyalar, əməliyyatlar və büdcələr \"{file}\" faylındakı məlumatlarla əvəz olunacaq. Bunu geri qaytarmaq olmaz.'**
  String backupRestoreConfirmBody(String file);

  /// No description provided for @backupRestoreConfirmAction.
  ///
  /// In az, this message translates to:
  /// **'Bərpa et'**
  String get backupRestoreConfirmAction;

  /// No description provided for @backupRestored.
  ///
  /// In az, this message translates to:
  /// **'Bərpa olundu: {transactions} əməliyyat, {accounts} hesab'**
  String backupRestored(int transactions, int accounts);

  /// No description provided for @backupReadFailed.
  ///
  /// In az, this message translates to:
  /// **'Fayl oxunmadı'**
  String get backupReadFailed;

  /// No description provided for @backupInvalidFile.
  ///
  /// In az, this message translates to:
  /// **'Bu fayl Gəlir-Çıxar ehtiyat nüsxəsi deyil'**
  String get backupInvalidFile;

  /// No description provided for @backupNewerVersion.
  ///
  /// In az, this message translates to:
  /// **'Ehtiyat nüsxə tətbiqin daha yeni versiyası ilə yaradılıb. Tətbiqi yeniləyin.'**
  String get backupNewerVersion;

  /// No description provided for @backupInvalidData.
  ///
  /// In az, this message translates to:
  /// **'Ehtiyat nüsxədəki məlumatlar zədəlidir. Heç nə dəyişdirilmədi.'**
  String get backupInvalidData;

  /// No description provided for @backupTooLarge.
  ///
  /// In az, this message translates to:
  /// **'Fayl çox böyükdür (maksimum 32 MB). Heç nə dəyişdirilmədi.'**
  String get backupTooLarge;

  /// No description provided for @txTypeToHolding.
  ///
  /// In az, this message translates to:
  /// **'Kənar yerə'**
  String get txTypeToHolding;

  /// No description provided for @txTypeFromHolding.
  ///
  /// In az, this message translates to:
  /// **'Kənar yerdən'**
  String get txTypeFromHolding;

  /// No description provided for @edit.
  ///
  /// In az, this message translates to:
  /// **'Redaktə et'**
  String get edit;

  /// No description provided for @notSet.
  ///
  /// In az, this message translates to:
  /// **'Təyin edilməyib'**
  String get notSet;

  /// No description provided for @holdings.
  ///
  /// In az, this message translates to:
  /// **'Kənar yerlər'**
  String get holdings;

  /// No description provided for @holdingsSubtitle.
  ///
  /// In az, this message translates to:
  /// **'Evdə, borcda, depozitdə, qızılda saxlanan pul'**
  String get holdingsSubtitle;

  /// No description provided for @holdingsTotal.
  ///
  /// In az, this message translates to:
  /// **'Kənarda'**
  String get holdingsTotal;

  /// No description provided for @holdingsElsewhere.
  ///
  /// In az, this message translates to:
  /// **'Kənarda'**
  String get holdingsElsewhere;

  /// No description provided for @netWorth.
  ///
  /// In az, this message translates to:
  /// **'Ümumi sərvət'**
  String get netWorth;

  /// No description provided for @addHolding.
  ///
  /// In az, this message translates to:
  /// **'Kənar yer əlavə et'**
  String get addHolding;

  /// No description provided for @editHolding.
  ///
  /// In az, this message translates to:
  /// **'Kənar yeri redaktə et'**
  String get editHolding;

  /// No description provided for @holdingNotFound.
  ///
  /// In az, this message translates to:
  /// **'Kənar yer tapılmadı'**
  String get holdingNotFound;

  /// No description provided for @holdingOpen.
  ///
  /// In az, this message translates to:
  /// **'Kənar yeri aç'**
  String get holdingOpen;

  /// No description provided for @emptyHoldingsTitle.
  ///
  /// In az, this message translates to:
  /// **'Kənar yer yoxdur'**
  String get emptyHoldingsTitle;

  /// No description provided for @emptyHoldingsBody.
  ///
  /// In az, this message translates to:
  /// **'Evdəki nağd pulu, yaxınınızdakı pulu, əmanəti və qızılı burada izləyin. Xərclənə bilən balansa daxil olmur, ümumi sərvətə daxildir.'**
  String get emptyHoldingsBody;

  /// No description provided for @holdingPlace.
  ///
  /// In az, this message translates to:
  /// **'Yer'**
  String get holdingPlace;

  /// No description provided for @holdingPlaceHomeCash.
  ///
  /// In az, this message translates to:
  /// **'Evdə nağd'**
  String get holdingPlaceHomeCash;

  /// No description provided for @holdingPlacePerson.
  ///
  /// In az, this message translates to:
  /// **'Yaxın adamda'**
  String get holdingPlacePerson;

  /// No description provided for @holdingPlaceBankDeposit.
  ///
  /// In az, this message translates to:
  /// **'Bank əmanəti'**
  String get holdingPlaceBankDeposit;

  /// No description provided for @holdingPlaceGold.
  ///
  /// In az, this message translates to:
  /// **'Qızıl, qiymətli əşya'**
  String get holdingPlaceGold;

  /// No description provided for @holdingPlaceOther.
  ///
  /// In az, this message translates to:
  /// **'Digər'**
  String get holdingPlaceOther;

  /// No description provided for @holdingNameHint.
  ///
  /// In az, this message translates to:
  /// **'Məs: Sandıq'**
  String get holdingNameHint;

  /// No description provided for @holdingInitialAmount.
  ///
  /// In az, this message translates to:
  /// **'Hazırkı məbləğ'**
  String get holdingInitialAmount;

  /// No description provided for @holdingCurrencyLocked.
  ///
  /// In az, this message translates to:
  /// **'Tarixçəsi olan kənar yerin valyutası dəyişdirilə bilməz.'**
  String get holdingCurrencyLocked;

  /// No description provided for @holdingInterestRate.
  ///
  /// In az, this message translates to:
  /// **'İllik faiz'**
  String get holdingInterestRate;

  /// No description provided for @holdingInterestInvalid.
  ///
  /// In az, this message translates to:
  /// **'0 ilə 100 arasında faiz daxil edin'**
  String get holdingInterestInvalid;

  /// No description provided for @holdingInterestValue.
  ///
  /// In az, this message translates to:
  /// **'İllik {rate}%'**
  String holdingInterestValue(String rate);

  /// No description provided for @holdingMaturityDate.
  ///
  /// In az, this message translates to:
  /// **'Bitmə tarixi'**
  String get holdingMaturityDate;

  /// No description provided for @holdingMaturityValue.
  ///
  /// In az, this message translates to:
  /// **'Bitmə: {date}'**
  String holdingMaturityValue(String date);

  /// No description provided for @holdingAdjust.
  ///
  /// In az, this message translates to:
  /// **'Məbləği dəyiş'**
  String get holdingAdjust;

  /// No description provided for @holdingEntryAdd.
  ///
  /// In az, this message translates to:
  /// **'Əlavə et'**
  String get holdingEntryAdd;

  /// No description provided for @holdingEntryWithdraw.
  ///
  /// In az, this message translates to:
  /// **'Götür'**
  String get holdingEntryWithdraw;

  /// No description provided for @holdingEntrySetValue.
  ///
  /// In az, this message translates to:
  /// **'Dəyəri yenilə'**
  String get holdingEntrySetValue;

  /// No description provided for @holdingNewValue.
  ///
  /// In az, this message translates to:
  /// **'Yeni dəyər'**
  String get holdingNewValue;

  /// No description provided for @holdingEntryFromAccount.
  ///
  /// In az, this message translates to:
  /// **'hesabdan köçürmə'**
  String get holdingEntryFromAccount;

  /// No description provided for @holdingErrorNegative.
  ///
  /// In az, this message translates to:
  /// **'Bu dəyişiklik məbləği sıfırdan aşağı salar'**
  String get holdingErrorNegative;

  /// No description provided for @holdingHistory.
  ///
  /// In az, this message translates to:
  /// **'Tarixçə'**
  String get holdingHistory;

  /// No description provided for @holdingNoEntries.
  ///
  /// In az, this message translates to:
  /// **'Hələ qeyd yoxdur'**
  String get holdingNoEntries;

  /// No description provided for @holdingMove.
  ///
  /// In az, this message translates to:
  /// **'Hesabla köçür'**
  String get holdingMove;

  /// No description provided for @holdingMoveIn.
  ///
  /// In az, this message translates to:
  /// **'Hesabdan bura'**
  String get holdingMoveIn;

  /// No description provided for @holdingMoveOut.
  ///
  /// In az, this message translates to:
  /// **'Buradan hesaba'**
  String get holdingMoveOut;

  /// No description provided for @holdingMoveAccountAmount.
  ///
  /// In az, this message translates to:
  /// **'Hesabda məbləğ ({code})'**
  String holdingMoveAccountAmount(String code);

  /// No description provided for @holdingMoveHoldingAmount.
  ///
  /// In az, this message translates to:
  /// **'Kənar yerdə məbləğ ({code})'**
  String holdingMoveHoldingAmount(String code);

  /// No description provided for @holdingMoveHint.
  ///
  /// In az, this message translates to:
  /// **'Köçürmə gəlir və ya xərc sayılmır, büdcələrə təsir etmir.'**
  String get holdingMoveHint;

  /// No description provided for @holdingMoveEditElsewhere.
  ///
  /// In az, this message translates to:
  /// **'Bu köçürmə Kənar yerlər bölməsindən idarə olunur'**
  String get holdingMoveEditElsewhere;

  /// No description provided for @deleteHoldingTitle.
  ///
  /// In az, this message translates to:
  /// **'Kənar yer silinsin?'**
  String get deleteHoldingTitle;

  /// No description provided for @deleteHoldingBody.
  ///
  /// In az, this message translates to:
  /// **'Kənar yer və bütün tarixçəsi birdəfəlik silinəcək.'**
  String get deleteHoldingBody;

  /// No description provided for @deleteHoldingUsedBody.
  ///
  /// In az, this message translates to:
  /// **'Bu kənar yerə hesablardan köçürmələr var, ona görə silinmir, arxivlənəcək.'**
  String get deleteHoldingUsedBody;

  /// No description provided for @holdingDeleted.
  ///
  /// In az, this message translates to:
  /// **'Kənar yer silindi'**
  String get holdingDeleted;

  /// No description provided for @holdingArchived.
  ///
  /// In az, this message translates to:
  /// **'Kənar yer arxivləndi'**
  String get holdingArchived;

  /// No description provided for @deleteHoldingEntryTitle.
  ///
  /// In az, this message translates to:
  /// **'Qeyd silinsin?'**
  String get deleteHoldingEntryTitle;

  /// No description provided for @deleteHoldingEntryLinkedBody.
  ///
  /// In az, this message translates to:
  /// **'Bu qeyd hesabdan köçürmə ilə yaradılıb. Hesabdakı əməliyyat da silinəcək.'**
  String get deleteHoldingEntryLinkedBody;

  /// No description provided for @exportHoldingsSection.
  ///
  /// In az, this message translates to:
  /// **'Kənar yerlər (cari vəziyyət)'**
  String get exportHoldingsSection;

  /// No description provided for @autoRates.
  ///
  /// In az, this message translates to:
  /// **'Avtomatik məzənnə (AMB)'**
  String get autoRates;

  /// No description provided for @autoRatesSubtitle.
  ///
  /// In az, this message translates to:
  /// **'Mərkəzi Bankın rəsmi məzənnələri, gündə ən çox 2 dəfə'**
  String get autoRatesSubtitle;

  /// No description provided for @ratesRefresh.
  ///
  /// In az, this message translates to:
  /// **'Yenilə'**
  String get ratesRefresh;

  /// No description provided for @ratesRefreshed.
  ///
  /// In az, this message translates to:
  /// **'Məzənnələr yeniləndi'**
  String get ratesRefreshed;

  /// No description provided for @ratesNeverUpdated.
  ///
  /// In az, this message translates to:
  /// **'Hələ yenilənməyib'**
  String get ratesNeverUpdated;

  /// No description provided for @ratesLastUpdated.
  ///
  /// In az, this message translates to:
  /// **'Yeniləndi: {when}'**
  String ratesLastUpdated(String when);

  /// No description provided for @ratesBulletinDate.
  ///
  /// In az, this message translates to:
  /// **'AMB tarixi: {date}'**
  String ratesBulletinDate(String date);

  /// No description provided for @ratesErrorOffline.
  ///
  /// In az, this message translates to:
  /// **'İnternet bağlantısı yoxdur. Sonra yenidən cəhd edin.'**
  String get ratesErrorOffline;

  /// No description provided for @ratesErrorServer.
  ///
  /// In az, this message translates to:
  /// **'AMB serveri cavab vermədi'**
  String get ratesErrorServer;

  /// No description provided for @ratesErrorParse.
  ///
  /// In az, this message translates to:
  /// **'AMB məlumatı oxunmadı və ya şübhəlidir. Köhnə məzənnələr saxlanıldı.'**
  String get ratesErrorParse;

  /// No description provided for @ratesPrivacyNote.
  ///
  /// In az, this message translates to:
  /// **'Yalnız cbar.az saytından ictimai məzənnə faylı yüklənir. Heç bir şəxsi məlumat göndərilmir.'**
  String get ratesPrivacyNote;

  /// No description provided for @rateSourceCbar.
  ///
  /// In az, this message translates to:
  /// **'AMB'**
  String get rateSourceCbar;

  /// No description provided for @rateSourceManual.
  ///
  /// In az, this message translates to:
  /// **'Əl ilə'**
  String get rateSourceManual;

  /// No description provided for @rateSourceDefault.
  ///
  /// In az, this message translates to:
  /// **'Standart'**
  String get rateSourceDefault;

  /// No description provided for @rateAutoValue.
  ///
  /// In az, this message translates to:
  /// **'AMB: {value}'**
  String rateAutoValue(String value);

  /// No description provided for @rateResetToAuto.
  ///
  /// In az, this message translates to:
  /// **'Avtomatik dəyərə qaytar'**
  String get rateResetToAuto;

  /// No description provided for @greetingMorning.
  ///
  /// In az, this message translates to:
  /// **'Sabahınız xeyir'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In az, this message translates to:
  /// **'Günortanız xeyir'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In az, this message translates to:
  /// **'Axşamınız xeyir'**
  String get greetingEvening;

  /// No description provided for @greetingNight.
  ///
  /// In az, this message translates to:
  /// **'Salam'**
  String get greetingNight;

  /// No description provided for @spendableBalance.
  ///
  /// In az, this message translates to:
  /// **'Xərclənə bilən balans'**
  String get spendableBalance;

  /// No description provided for @thisWeek.
  ///
  /// In az, this message translates to:
  /// **'Bu həftə'**
  String get thisWeek;

  /// No description provided for @vsLastWeekLess.
  ///
  /// In az, this message translates to:
  /// **'Keçən həftədən {percent}% az'**
  String vsLastWeekLess(int percent);

  /// No description provided for @vsLastWeekMore.
  ///
  /// In az, this message translates to:
  /// **'Keçən həftədən {percent}% çox'**
  String vsLastWeekMore(int percent);

  /// No description provided for @createBudget.
  ///
  /// In az, this message translates to:
  /// **'Büdcə yarat'**
  String get createBudget;

  /// No description provided for @depositEndsIn.
  ///
  /// In az, this message translates to:
  /// **'{days, plural, =0{Əmanətin müddəti bu gün bitir} other{Əmanətin müddəti {days} gün sonra bitir}}'**
  String depositEndsIn(int days);

  /// No description provided for @depositMatured.
  ///
  /// In az, this message translates to:
  /// **'Müddəti bitib'**
  String get depositMatured;

  /// No description provided for @daysLeft.
  ///
  /// In az, this message translates to:
  /// **'{days, plural, =0{bu gün bitir} other{{days} gün qalıb}}'**
  String daysLeft(int days);

  /// No description provided for @ratesUpdatedAt.
  ///
  /// In az, this message translates to:
  /// **'Məzənnələr yeniləndi · {time}'**
  String ratesUpdatedAt(String time);

  /// No description provided for @ratesOfflineUsingLast.
  ///
  /// In az, this message translates to:
  /// **'Oflayn: son məzənnələr istifadə olunur ({date})'**
  String ratesOfflineUsingLast(String date);

  /// No description provided for @onboardingSkip.
  ///
  /// In az, this message translates to:
  /// **'Keç'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In az, this message translates to:
  /// **'Davam et'**
  String get onboardingNext;

  /// No description provided for @onboardingStart.
  ///
  /// In az, this message translates to:
  /// **'Başla'**
  String get onboardingStart;

  /// No description provided for @onboardingPageOf.
  ///
  /// In az, this message translates to:
  /// **'Səhifə {page} / {total}'**
  String onboardingPageOf(int page, int total);

  /// No description provided for @onb1Title.
  ///
  /// In az, this message translates to:
  /// **'Gəlir və xərcini bir yerdə gör'**
  String get onb1Title;

  /// No description provided for @onb1Body.
  ///
  /// In az, this message translates to:
  /// **'Hər əməliyyatı saniyələr içində qeyd et. İnternet lazım deyil.'**
  String get onb1Body;

  /// No description provided for @onb2Title.
  ///
  /// In az, this message translates to:
  /// **'Büdcə qur, limitdən xəbərdar ol'**
  String get onb2Title;

  /// No description provided for @onb2Body.
  ///
  /// In az, this message translates to:
  /// **'Limitin 80%-nə çatanda xəbərdarlıq edirik.'**
  String get onb2Body;

  /// No description provided for @onb3Title.
  ///
  /// In az, this message translates to:
  /// **'Bütün sərvətini izlə'**
  String get onb3Title;

  /// No description provided for @onb3Body.
  ///
  /// In az, this message translates to:
  /// **'Evdəki nağd pul, əmanət, qızıl: hamısı «Ümumi sərvət»də.'**
  String get onb3Body;

  /// No description provided for @chooseLanguage.
  ///
  /// In az, this message translates to:
  /// **'Tətbiqin dili'**
  String get chooseLanguage;

  /// No description provided for @baseCurrencyAzn.
  ///
  /// In az, this message translates to:
  /// **'Əsas valyuta: Azərbaycan manatı'**
  String get baseCurrencyAzn;

  /// No description provided for @aznName.
  ///
  /// In az, this message translates to:
  /// **'Azərbaycan manatı'**
  String get aznName;

  /// No description provided for @baseCurrencyBody.
  ///
  /// In az, this message translates to:
  /// **'Bütün cəmlər AZN-də göstərilir. USD/EUR hesablar məzənnə ilə çevrilir.'**
  String get baseCurrencyBody;

  /// No description provided for @protectWithPin.
  ///
  /// In az, this message translates to:
  /// **'Tətbiqi PIN ilə qoru'**
  String get protectWithPin;

  /// No description provided for @protectWithPinBody.
  ///
  /// In az, this message translates to:
  /// **'Telefonunuz başqasının əlinə keçsə belə maliyyə məlumatlarınız gizli qalır.'**
  String get protectWithPinBody;

  /// No description provided for @setPin.
  ///
  /// In az, this message translates to:
  /// **'PIN qur'**
  String get setPin;

  /// No description provided for @later.
  ///
  /// In az, this message translates to:
  /// **'Sonra'**
  String get later;

  /// No description provided for @pinIsSet.
  ///
  /// In az, this message translates to:
  /// **'PIN quruldu'**
  String get pinIsSet;

  /// No description provided for @autoRatesOnboardingTitle.
  ///
  /// In az, this message translates to:
  /// **'Məzənnələri avtomatik yenilə'**
  String get autoRatesOnboardingTitle;

  /// No description provided for @appearance.
  ///
  /// In az, this message translates to:
  /// **'Görünüş'**
  String get appearance;

  /// No description provided for @themeColour.
  ///
  /// In az, this message translates to:
  /// **'Rəng seçin'**
  String get themeColour;

  /// No description provided for @wallpaperColour.
  ///
  /// In az, this message translates to:
  /// **'Divar kağızı rəngləri'**
  String get wallpaperColour;

  /// No description provided for @wallpaperColourBody.
  ///
  /// In az, this message translates to:
  /// **'Android 12+ divar kağızından rəng götürür'**
  String get wallpaperColourBody;

  /// No description provided for @wallpaperColourActive.
  ///
  /// In az, this message translates to:
  /// **'Divar kağızı rəngi aktivdir'**
  String get wallpaperColourActive;

  /// No description provided for @preview.
  ///
  /// In az, this message translates to:
  /// **'Önizləmə'**
  String get preview;

  /// No description provided for @seedSelected.
  ///
  /// In az, this message translates to:
  /// **'{name}, seçilib'**
  String seedSelected(String name);

  /// No description provided for @settingsNotifications.
  ///
  /// In az, this message translates to:
  /// **'Bildirişlər'**
  String get settingsNotifications;

  /// No description provided for @ratesSection.
  ///
  /// In az, this message translates to:
  /// **'Məzənnələr'**
  String get ratesSection;

  /// No description provided for @autoRatesShort.
  ///
  /// In az, this message translates to:
  /// **'Avtomatik yenilə'**
  String get autoRatesShort;

  /// No description provided for @autoRatesSource.
  ///
  /// In az, this message translates to:
  /// **'Mənbə: AMB (cbar.az)'**
  String get autoRatesSource;

  /// No description provided for @ratesUpdating.
  ///
  /// In az, this message translates to:
  /// **'Yenilənir…'**
  String get ratesUpdating;

  /// No description provided for @ratesUpdatingShort.
  ///
  /// In az, this message translates to:
  /// **'Yenilənir'**
  String get ratesUpdatingShort;

  /// No description provided for @ratesLastUpdatedShort.
  ///
  /// In az, this message translates to:
  /// **'Son yenilənmə: {when}'**
  String ratesLastUpdatedShort(String when);

  /// No description provided for @ratesStaleSuffix.
  ///
  /// In az, this message translates to:
  /// **'(köhnəlib)'**
  String get ratesStaleSuffix;

  /// No description provided for @ratesOfflineSince.
  ///
  /// In az, this message translates to:
  /// **'Oflayn. Son məzənnələr: {when}'**
  String ratesOfflineSince(String when);

  /// No description provided for @ratesNotUpdated.
  ///
  /// In az, this message translates to:
  /// **'Yenilənmədi'**
  String get ratesNotUpdated;

  /// No description provided for @ratesNotUpdatedSince.
  ///
  /// In az, this message translates to:
  /// **'Yenilənmədi. Son məzənnələr: {date}'**
  String ratesNotUpdatedSince(String date);

  /// No description provided for @ratesNeverFetchedOffline.
  ///
  /// In az, this message translates to:
  /// **'Hələ yüklənməyib. Əl ilə daxil edilən məzənnələr istifadə olunur.'**
  String get ratesNeverFetchedOffline;

  /// No description provided for @retry.
  ///
  /// In az, this message translates to:
  /// **'Yenidən cəhd et'**
  String get retry;

  /// No description provided for @ratesUnitHeader.
  ///
  /// In az, this message translates to:
  /// **'1 vahid = ? AZN'**
  String get ratesUnitHeader;

  /// No description provided for @manualOverrideNote.
  ///
  /// In az, this message translates to:
  /// **'Əl ilə daxil edilən məzənnə avtomatik yenilənmədə dəyişmir.'**
  String get manualOverrideNote;

  /// No description provided for @resetToCbar.
  ///
  /// In az, this message translates to:
  /// **'AMB məzənnəsinə qaytar'**
  String get resetToCbar;

  /// No description provided for @holdingsShareOfNetWorth.
  ///
  /// In az, this message translates to:
  /// **'Ümumi sərvətin {percent}%-i'**
  String holdingsShareOfNetWorth(int percent);

  /// No description provided for @holdingsPlaceCount.
  ///
  /// In az, this message translates to:
  /// **'{count, plural, =1{1 yer} other{{count} yer}}'**
  String holdingsPlaceCount(int count);

  /// No description provided for @holdingsZeroGroup.
  ///
  /// In az, this message translates to:
  /// **'Sıfır qalıqlılar ({count})'**
  String holdingsZeroGroup(int count);

  /// No description provided for @updatedToday.
  ///
  /// In az, this message translates to:
  /// **'bu gün yeniləndi'**
  String get updatedToday;

  /// No description provided for @updatedDaysAgo.
  ///
  /// In az, this message translates to:
  /// **'{days, plural, =1{1 gün əvvəl yeniləndi} other{{days} gün əvvəl yeniləndi}}'**
  String updatedDaysAgo(int days);

  /// No description provided for @holdingDeleteConfirm.
  ///
  /// In az, this message translates to:
  /// **'«{name}» silinsin?'**
  String holdingDeleteConfirm(String name);

  /// No description provided for @holdingCurrentAmount.
  ///
  /// In az, this message translates to:
  /// **'indiki {amount}'**
  String holdingCurrentAmount(String amount);

  /// No description provided for @holdingNewBalance.
  ///
  /// In az, this message translates to:
  /// **'Yeni qalıq: {amount}'**
  String holdingNewBalance(String amount);

  /// No description provided for @holdingDifference.
  ///
  /// In az, this message translates to:
  /// **'Fərq: {amount}'**
  String holdingDifference(String amount);

  /// No description provided for @withdrawTooMuch.
  ///
  /// In az, this message translates to:
  /// **'Qalıqdan çox götürmək olmaz'**
  String get withdrawTooMuch;

  /// No description provided for @linkFromAccount.
  ///
  /// In az, this message translates to:
  /// **'Hesabdan köçür'**
  String get linkFromAccount;

  /// No description provided for @linkToAccount.
  ///
  /// In az, this message translates to:
  /// **'Hesaba köçür'**
  String get linkToAccount;

  /// No description provided for @holdingUpdateValue.
  ///
  /// In az, this message translates to:
  /// **'Dəyəri yenilə'**
  String get holdingUpdateValue;

  /// No description provided for @holdingValueShort.
  ///
  /// In az, this message translates to:
  /// **'Dəyər'**
  String get holdingValueShort;

  /// No description provided for @estimatedInterest.
  ///
  /// In az, this message translates to:
  /// **'Təxmini gəlir'**
  String get estimatedInterest;

  /// No description provided for @range3m.
  ///
  /// In az, this message translates to:
  /// **'3A'**
  String get range3m;

  /// No description provided for @range6m.
  ///
  /// In az, this message translates to:
  /// **'6A'**
  String get range6m;

  /// No description provided for @range1y.
  ///
  /// In az, this message translates to:
  /// **'1İ'**
  String get range1y;

  /// No description provided for @chartNeedsTwoPoints.
  ///
  /// In az, this message translates to:
  /// **'Qrafik üçün ən azı 2 qeyd lazımdır'**
  String get chartNeedsTwoPoints;

  /// No description provided for @holdingAdded.
  ///
  /// In az, this message translates to:
  /// **'Əlavə edildi'**
  String get holdingAdded;

  /// No description provided for @holdingWithdrawn.
  ///
  /// In az, this message translates to:
  /// **'Götürüldü'**
  String get holdingWithdrawn;

  /// No description provided for @holdingValueSet.
  ///
  /// In az, this message translates to:
  /// **'Dəyər yeniləndi'**
  String get holdingValueSet;

  /// No description provided for @holdingBefore.
  ///
  /// In az, this message translates to:
  /// **'əvvəl {amount}'**
  String holdingBefore(String amount);

  /// No description provided for @fromAccountName.
  ///
  /// In az, this message translates to:
  /// **'{name} hesabından'**
  String fromAccountName(String name);

  /// No description provided for @toAccountName.
  ///
  /// In az, this message translates to:
  /// **'{name} hesabına'**
  String toAccountName(String name);

  /// No description provided for @holdingNameHintPerson.
  ///
  /// In az, this message translates to:
  /// **'Məs: Anamda'**
  String get holdingNameHintPerson;

  /// No description provided for @holdingNameHintDeposit.
  ///
  /// In az, this message translates to:
  /// **'Məs: Kapital 12 ay'**
  String get holdingNameHintDeposit;

  /// No description provided for @holdingNameHintGold.
  ///
  /// In az, this message translates to:
  /// **'Məs: Qızıl üzük'**
  String get holdingNameHintGold;

  /// No description provided for @holdingFromAccount.
  ///
  /// In az, this message translates to:
  /// **'Məbləği hesabdan köçür'**
  String get holdingFromAccount;

  /// No description provided for @holdingCurrencyLockedHelper.
  ///
  /// In az, this message translates to:
  /// **'Tarixçə olduğu üçün valyuta dəyişmir'**
  String get holdingCurrencyLockedHelper;

  /// No description provided for @maturityAfterToday.
  ///
  /// In az, this message translates to:
  /// **'Bitmə tarixi bu gündən sonra olmalıdır'**
  String get maturityAfterToday;

  /// No description provided for @holdingMoveChip.
  ///
  /// In az, this message translates to:
  /// **'Kənar yer'**
  String get holdingMoveChip;

  /// No description provided for @rateJumpTitle.
  ///
  /// In az, this message translates to:
  /// **'Məzənnə kəskin dəyişib'**
  String get rateJumpTitle;

  /// No description provided for @rateJumpBody.
  ///
  /// In az, this message translates to:
  /// **'AMB-dən gələn bu məzənnələr əvvəlkindən 50%-dən çox fərqlənir. Tətbiq edilsin?'**
  String get rateJumpBody;

  /// No description provided for @rateJumpKeep.
  ///
  /// In az, this message translates to:
  /// **'Köhnəni saxla'**
  String get rateJumpKeep;

  /// No description provided for @rateJumpApply.
  ///
  /// In az, this message translates to:
  /// **'Tətbiq et'**
  String get rateJumpApply;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['az', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'az':
      return AppLocalizationsAz();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
