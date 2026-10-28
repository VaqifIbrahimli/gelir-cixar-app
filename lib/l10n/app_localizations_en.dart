// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Gəlir-Çıxar';

  @override
  String get navHome => 'Home';

  @override
  String get navTransactions => 'Transactions';

  @override
  String get navReports => 'Reports';

  @override
  String get navBudgets => 'Budgets';

  @override
  String get navSettings => 'Settings';

  @override
  String get genericError => 'Something went wrong';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get close => 'Close';

  @override
  String get confirm => 'Confirm';

  @override
  String get clear => 'Clear';

  @override
  String get more => 'More';

  @override
  String get undo => 'Undo';

  @override
  String get all => 'All';

  @override
  String get seeAll => 'See all';

  @override
  String get total => 'Total';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get income => 'Income';

  @override
  String get expense => 'Expense';

  @override
  String get net => 'Net';

  @override
  String get txTypeIncome => 'Income';

  @override
  String get txTypeExpense => 'Expense';

  @override
  String get txTypeTransfer => 'Transfer';

  @override
  String get uncategorized => 'Uncategorized';

  @override
  String get totalBalance => 'Total balance';

  @override
  String get showBalance => 'Show balance';

  @override
  String get hideBalance => 'Hide balance';

  @override
  String get balanceHidden => 'Balance hidden';

  @override
  String get negativeBalance => 'Negative balance';

  @override
  String thisMonth(String month) {
    return 'This month: $month';
  }

  @override
  String get recentTransactions => 'Recent transactions';

  @override
  String get accounts => 'Accounts';

  @override
  String get account => 'Account';

  @override
  String get addAccount => 'Add account';

  @override
  String get newAccount => 'New account';

  @override
  String get editAccount => 'Edit account';

  @override
  String get accountNotFound => 'Account not found';

  @override
  String get accountType => 'Account type';

  @override
  String get accountTypeCash => 'Cash';

  @override
  String get accountTypeCard => 'Card';

  @override
  String get accountTypeBank => 'Bank account';

  @override
  String get accountTypeSavings => 'Savings';

  @override
  String get currency => 'Currency';

  @override
  String get currencyLockedHint =>
      'The currency of an account with transactions can\'t be changed.';

  @override
  String get initialBalance => 'Initial balance';

  @override
  String get color => 'Colour';

  @override
  String colorN(int n) {
    return 'Colour $n';
  }

  @override
  String get name => 'Name';

  @override
  String get nameRequired => 'Enter a name';

  @override
  String get archive => 'Archive';

  @override
  String get unarchive => 'Unarchive';

  @override
  String get archived => 'archived';

  @override
  String archivedCount(int count) {
    return 'Archived ($count)';
  }

  @override
  String get deleteAccountTitle => 'Delete account?';

  @override
  String get deleteAccountBody => 'This account will be deleted permanently.';

  @override
  String get deleteAccountUsedBody =>
      'This account has transactions, so it will be archived instead of deleted. Its history is kept.';

  @override
  String get accountDeleted => 'Account deleted';

  @override
  String get accountArchived => 'Account archived';

  @override
  String get emptyAccountsTitle => 'Add your first account';

  @override
  String get categories => 'Categories';

  @override
  String get category => 'Category';

  @override
  String get newCategory => 'New category';

  @override
  String get editCategory => 'Edit category';

  @override
  String get categoryNotFound => 'Category not found';

  @override
  String get nameAz => 'Name (Azerbaijani)';

  @override
  String get nameEn => 'Name (English)';

  @override
  String get nameEnHint => 'If empty, the Azerbaijani name is shown';

  @override
  String get icon => 'Icon';

  @override
  String transactionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '1 transaction',
      zero: 'No transactions',
    );
    return '$_temp0';
  }

  @override
  String get deleteCategoryTitle => 'Delete category?';

  @override
  String get deleteCategoryBody => 'This category will be deleted permanently.';

  @override
  String get deleteCategoryUsedBody =>
      'This category is in use, so it will be archived instead of deleted.';

  @override
  String get categoryDeleted => 'Category deleted';

  @override
  String get categoryArchived => 'Category archived';

  @override
  String get emptyCategoriesTitle => 'No categories';

  @override
  String get addTransaction => 'Add transaction';

  @override
  String get newTransaction => 'New transaction';

  @override
  String get editTransaction => 'Edit transaction';

  @override
  String get transactionNotFound => 'Transaction not found';

  @override
  String get emptyTransactionsTitle => 'No transactions yet';

  @override
  String get emptyTransactionsBody => 'Add your first income or expense.';

  @override
  String get emptyFilteredTitle => 'Nothing matches these filters';

  @override
  String get resetFilters => 'Reset filters';

  @override
  String get search => 'Search';

  @override
  String get closeSearch => 'Close search';

  @override
  String get searchNotes => 'Search notes';

  @override
  String get allAccounts => 'All accounts';

  @override
  String get allCategories => 'All categories';

  @override
  String get dateRange => 'Dates';

  @override
  String get date => 'Date';

  @override
  String get note => 'Note';

  @override
  String get addNote => 'Add note';

  @override
  String get noteHint => 'e.g. Grocery store';

  @override
  String get fromAccount => 'From';

  @override
  String get toAccount => 'To';

  @override
  String get amountSent => 'Sent';

  @override
  String get amountReceived => 'Received';

  @override
  String get transactionDeleted => 'Transaction deleted';

  @override
  String get deleteTransactionTitle => 'Delete transaction?';

  @override
  String get deleteTransactionBody => 'This transaction will be deleted.';

  @override
  String get enterAmount => 'Enter an amount';

  @override
  String get invalidAmount => 'Invalid amount';

  @override
  String get enterReceivedAmount => 'Enter the received amount';

  @override
  String get selectAccount => 'Choose an account';

  @override
  String get selectToAccount => 'Choose the destination account';

  @override
  String get sameAccountError => 'Choose two different accounts';

  @override
  String get selectCategory => 'Choose a category';

  @override
  String get backspace => 'Backspace';

  @override
  String get backspaceHint => 'Long-press to clear';

  @override
  String get plus => 'Plus';

  @override
  String get plusHint => 'Long-press for multiply (×)';

  @override
  String get minus => 'Minus';

  @override
  String get minusHint => 'Long-press for divide (÷)';

  @override
  String get decimalPoint => 'Decimal point';

  @override
  String get equals => 'Equals';

  @override
  String get enterPin => 'Enter your PIN';

  @override
  String get enterCurrentPin => 'Enter your current PIN';

  @override
  String get createPin => 'Create a PIN';

  @override
  String get confirmPin => 'Enter the PIN again';

  @override
  String get pinLengthHint => '4–6 digits, then tap ✓';

  @override
  String get pinMismatch => 'The PINs don\'t match. Try again.';

  @override
  String get pinSetupIntro =>
      'Set a PIN to protect your data. You can turn the lock off later in Settings.';

  @override
  String pinDigitsEntered(int entered, int total) {
    return '$entered of $total digits entered';
  }

  @override
  String wrongPinAttemptsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Wrong PIN. $count attempts left',
      one: 'Wrong PIN. 1 attempt left',
      zero: 'Wrong PIN',
    );
    return '$_temp0';
  }

  @override
  String lockedOutFor(int seconds) {
    return 'Too many wrong attempts. Wait $seconds s.';
  }

  @override
  String get useFingerprint => 'Unlock with fingerprint';

  @override
  String get biometricReason => 'Confirm to unlock Gəlir-Çıxar';

  @override
  String get biometricEnableReason => 'Confirm to turn on fingerprint unlock';

  @override
  String get biometricUnavailable =>
      'No fingerprint is enrolled, or this device doesn\'t support it';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsSecurity => 'Security';

  @override
  String get settingsData => 'Data';

  @override
  String get settingsAbout => 'About';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get baseCurrency => 'Base currency';

  @override
  String get appLock => 'App lock';

  @override
  String get appLockSubtitle => 'Ask for a PIN on launch';

  @override
  String get changePin => 'Change PIN';

  @override
  String get fingerprint => 'Fingerprint';

  @override
  String get fingerprintSubtitle =>
      'Unlock with a fingerprint instead of the PIN';

  @override
  String get about => 'About the app';

  @override
  String get aboutBody =>
      'Offline personal income and expense tracker. All data stays on this device.';

  @override
  String versionN(String version) {
    return 'Version $version';
  }

  @override
  String get addBudget => 'Add budget';

  @override
  String get editBudget => 'Edit budget';

  @override
  String get deleteBudgetTitle => 'Delete budget?';

  @override
  String get budgetLimit => 'Monthly limit';

  @override
  String get budgetTotal => 'Total budget';

  @override
  String get budgetSummary => 'Budget summary';

  @override
  String budgetRemaining(String amount) {
    return 'Left: $amount';
  }

  @override
  String budgetOverBy(String amount) {
    return 'Over by $amount';
  }

  @override
  String get budgetStateWarning => 'warning';

  @override
  String get budgetStateOver => 'over budget';

  @override
  String budgetSemantics(String name, int percent) {
    return '$name budget, $percent percent used';
  }

  @override
  String budgetDailyAllowance(String amount, int days) {
    return 'Daily allowance: $amount ($days days left)';
  }

  @override
  String budgetsNearLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count categories are near or over their limits',
      one: '1 category is near or over its limit',
    );
    return '$_temp0';
  }

  @override
  String get budgetsCopyLastMonth => 'Copy last month\'s budgets';

  @override
  String budgetsCopied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count budgets copied',
      one: '1 budget copied',
    );
    return '$_temp0';
  }

  @override
  String get budgetsCopyNone => 'Nothing to copy from last month';

  @override
  String get budgetAllCategoriesUsed =>
      'Every expense category already has a budget this month.';

  @override
  String get emptyBudgetsTitle => 'No budgets yet';

  @override
  String get emptyBudgetsBody =>
      'Set monthly limits for categories and keep spending in check.';

  @override
  String get positiveAmountRequired => 'Enter a positive amount';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String budgetAlertWarningTitle(String name) {
    return '$name: approaching the budget limit';
  }

  @override
  String budgetAlertWarningBody(int percent, String amounts) {
    return '$percent% of the limit used ($amounts)';
  }

  @override
  String budgetAlertOverTitle(String name) {
    return '$name: budget limit exceeded';
  }

  @override
  String budgetAlertOverBody(String amounts) {
    return 'Spent: $amounts';
  }

  @override
  String get notificationChannelName => 'Budget alerts';

  @override
  String get notificationChannelDescription =>
      'When a budget reaches 80% or 100% of its limit';

  @override
  String get budgetNotifications => 'Budget notifications';

  @override
  String get budgetNotificationsSubtitle => 'Notify at 80% and 100% of a limit';

  @override
  String get notificationsDenied =>
      'Notification permission was denied. You can allow it in system settings.';

  @override
  String get periodThisMonth => 'This month';

  @override
  String get periodLastMonth => 'Last month';

  @override
  String get periodThisYear => 'This year';

  @override
  String get periodCustom => 'Custom';

  @override
  String get emptyReportsTitle => 'No data for this period';

  @override
  String get otherCategories => 'Other';

  @override
  String get reportsByMonth => 'By month';

  @override
  String monthsN(int count) {
    return '$count mo';
  }

  @override
  String averageMonthlyExpense(String amount) {
    return 'Average monthly expense: $amount';
  }

  @override
  String get balanceTrend => 'Balance trend';

  @override
  String get balanceTrendHint =>
      'Total balance at each month end (from income and expenses, AZN).';

  @override
  String get exchangeRates => 'Exchange rates';

  @override
  String get exchangeRatesSubtitle => 'USD, EUR, RUB, TRY → AZN';

  @override
  String get exchangeRatesHint =>
      'Enter how many manat one unit of each currency is worth. All totals are converted with these rates.';

  @override
  String rateLabel(String code) {
    return '$code rate';
  }

  @override
  String get ratePositive => 'Enter a positive number (e.g. 1.70)';

  @override
  String get ratesSaved => 'Rates saved';

  @override
  String get blockScreenshots => 'Block screenshots';

  @override
  String get blockScreenshotsSubtitle =>
      'Prevents screenshots and the recent-apps preview';

  @override
  String get export => 'Export';

  @override
  String get exportSubtitle => 'CSV, Excel or PDF';

  @override
  String get exportFormat => 'Format';

  @override
  String get exportPeriod => 'Period';

  @override
  String get exportAction => 'Export and share';

  @override
  String get exportHint =>
      'The file is created in a temporary folder and the share sheet opens.';

  @override
  String get exportNothing => 'No transactions in the selected period';

  @override
  String get exportFailed => 'Export failed';

  @override
  String get exportShareTitle => 'Share report';

  @override
  String get exportPdfTitle => 'Gəlir-Çıxar report';

  @override
  String get exportGenerated => 'Generated';

  @override
  String get exportColDate => 'Date';

  @override
  String get exportColType => 'Type';

  @override
  String get exportColAmount => 'Amount';

  @override
  String get exportColAmountAzn => 'Amount (AZN)';

  @override
  String get exportColToAmount => 'Received amount';

  @override
  String get backupCreate => 'Create backup';

  @override
  String get backupCreateSubtitle => 'All data to a JSON file';

  @override
  String get backupShareSubject => 'Gəlir-Çıxar backup';

  @override
  String get backupFailed => 'Backup failed';

  @override
  String get backupRestore => 'Restore from backup';

  @override
  String get backupRestoreSubtitle => 'Replaces the current data';

  @override
  String get backupRestoreConfirmTitle => 'Replace all data?';

  @override
  String backupRestoreConfirmBody(String file) {
    return 'All current accounts, categories, transactions and budgets will be replaced with the data in \"$file\". This can\'t be undone.';
  }

  @override
  String get backupRestoreConfirmAction => 'Restore';

  @override
  String backupRestored(int transactions, int accounts) {
    return 'Restored: $transactions transactions, $accounts accounts';
  }

  @override
  String get backupReadFailed => 'Couldn\'t read the file';

  @override
  String get backupInvalidFile => 'This file is not a Gəlir-Çıxar backup';

  @override
  String get backupNewerVersion =>
      'The backup was made by a newer app version. Update the app first.';

  @override
  String get backupInvalidData =>
      'The backup data is damaged. Nothing was changed.';

  @override
  String get backupTooLarge =>
      'The file is too large (max 32 MB). Nothing was changed.';

  @override
  String get txTypeToHolding => 'To holding';

  @override
  String get txTypeFromHolding => 'From holding';

  @override
  String get edit => 'Edit';

  @override
  String get notSet => 'Not set';

  @override
  String get holdings => 'Money elsewhere';

  @override
  String get holdingsSubtitle => 'Cash at home, lent money, deposits, gold';

  @override
  String get holdingsTotal => 'Held elsewhere';

  @override
  String get holdingsElsewhere => 'Held elsewhere';

  @override
  String get netWorth => 'Net worth';

  @override
  String get addHolding => 'Add holding';

  @override
  String get editHolding => 'Edit holding';

  @override
  String get holdingNotFound => 'Holding not found';

  @override
  String get holdingOpen => 'Open holding';

  @override
  String get emptyHoldingsTitle => 'No money elsewhere yet';

  @override
  String get emptyHoldingsBody =>
      'Track cash at home, money with someone you know, deposits and gold here. It isn\'t part of the spendable balance, but it is part of your net worth.';

  @override
  String get holdingPlace => 'Place';

  @override
  String get holdingPlaceHomeCash => 'Cash at home';

  @override
  String get holdingPlacePerson => 'With a person';

  @override
  String get holdingPlaceBankDeposit => 'Bank deposit';

  @override
  String get holdingPlaceGold => 'Gold and valuables';

  @override
  String get holdingPlaceOther => 'Other';

  @override
  String get holdingNameHint => 'e.g. Home safe';

  @override
  String get holdingInitialAmount => 'Current amount';

  @override
  String get holdingCurrencyLocked =>
      'The currency can\'t be changed once the holding has history.';

  @override
  String get holdingInterestRate => 'Annual interest';

  @override
  String get holdingInterestInvalid => 'Enter a rate between 0 and 100';

  @override
  String holdingInterestValue(String rate) {
    return '$rate% a year';
  }

  @override
  String get holdingMaturityDate => 'Maturity date';

  @override
  String holdingMaturityValue(String date) {
    return 'Matures $date';
  }

  @override
  String get holdingAdjust => 'Adjust amount';

  @override
  String get holdingEntryAdd => 'Add';

  @override
  String get holdingEntryWithdraw => 'Withdraw';

  @override
  String get holdingEntrySetValue => 'Update value';

  @override
  String get holdingNewValue => 'New value';

  @override
  String get holdingEntryFromAccount => 'account move';

  @override
  String get holdingErrorNegative => 'This would take the amount below zero';

  @override
  String get holdingHistory => 'History';

  @override
  String get holdingNoEntries => 'No entries yet';

  @override
  String get holdingMove => 'Move with account';

  @override
  String get holdingMoveIn => 'Account → here';

  @override
  String get holdingMoveOut => 'Here → account';

  @override
  String holdingMoveAccountAmount(String code) {
    return 'Amount in account ($code)';
  }

  @override
  String holdingMoveHoldingAmount(String code) {
    return 'Amount in holding ($code)';
  }

  @override
  String get holdingMoveHint =>
      'A move is neither income nor expense and doesn\'t affect budgets.';

  @override
  String get holdingMoveEditElsewhere =>
      'This move is managed from Money elsewhere';

  @override
  String get deleteHoldingTitle => 'Delete holding?';

  @override
  String get deleteHoldingBody =>
      'The holding and its whole history will be deleted permanently.';

  @override
  String get deleteHoldingUsedBody =>
      'Accounts have moves with this holding, so it will be archived instead of deleted.';

  @override
  String get holdingDeleted => 'Holding deleted';

  @override
  String get holdingArchived => 'Holding archived';

  @override
  String get deleteHoldingEntryTitle => 'Delete entry?';

  @override
  String get deleteHoldingEntryLinkedBody =>
      'This entry came from an account move. The account transaction will be deleted too.';

  @override
  String get exportHoldingsSection => 'Money elsewhere (current)';

  @override
  String get autoRates => 'Automatic rates (CBAR)';

  @override
  String get autoRatesSubtitle =>
      'Official Central Bank rates, at most twice a day';

  @override
  String get ratesRefresh => 'Refresh';

  @override
  String get ratesRefreshed => 'Rates updated';

  @override
  String get ratesNeverUpdated => 'Not updated yet';

  @override
  String ratesLastUpdated(String when) {
    return 'Updated $when';
  }

  @override
  String ratesBulletinDate(String date) {
    return 'CBAR date: $date';
  }

  @override
  String get ratesErrorOffline => 'No internet connection. Try again later.';

  @override
  String get ratesErrorServer => 'The CBAR server didn\'t respond';

  @override
  String get ratesErrorParse =>
      'The CBAR data couldn\'t be read or looked wrong. The previous rates were kept.';

  @override
  String get ratesPrivacyNote =>
      'Only the public rate file is downloaded from cbar.az. No personal data is sent.';

  @override
  String get rateSourceCbar => 'CBAR';

  @override
  String get rateSourceManual => 'Manual';

  @override
  String get rateSourceDefault => 'Default';

  @override
  String rateAutoValue(String value) {
    return 'CBAR: $value';
  }

  @override
  String get rateResetToAuto => 'Back to automatic';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingAfternoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String get greetingNight => 'Hello';

  @override
  String get spendableBalance => 'Spendable balance';

  @override
  String get thisWeek => 'This week';

  @override
  String vsLastWeekLess(int percent) {
    return '$percent% less than last week';
  }

  @override
  String vsLastWeekMore(int percent) {
    return '$percent% more than last week';
  }

  @override
  String get createBudget => 'Create budget';

  @override
  String depositEndsIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'A deposit matures in $days days',
      one: 'A deposit matures in 1 day',
      zero: 'A deposit matures today',
    );
    return '$_temp0';
  }

  @override
  String get depositMatured => 'Matured';

  @override
  String daysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days left',
      one: '1 day left',
      zero: 'ends today',
    );
    return '$_temp0';
  }

  @override
  String ratesUpdatedAt(String time) {
    return 'Rates updated · $time';
  }

  @override
  String ratesOfflineUsingLast(String date) {
    return 'Offline: using the last rates ($date)';
  }

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Continue';

  @override
  String get onboardingStart => 'Start';

  @override
  String onboardingPageOf(int page, int total) {
    return 'Page $page of $total';
  }

  @override
  String get onb1Title => 'See income and spending in one place';

  @override
  String get onb1Body =>
      'Log every transaction in seconds. No internet needed.';

  @override
  String get onb2Title => 'Set budgets, stay under the limit';

  @override
  String get onb2Body => 'We warn you at 80% of a limit.';

  @override
  String get onb3Title => 'Track everything you own';

  @override
  String get onb3Body => 'Cash at home, deposits, gold: all in your net worth.';

  @override
  String get chooseLanguage => 'App language';

  @override
  String get baseCurrencyAzn => 'Base currency: Azerbaijani manat';

  @override
  String get aznName => 'Azerbaijani manat';

  @override
  String get baseCurrencyBody =>
      'All totals are shown in AZN. USD/EUR accounts are converted with exchange rates.';

  @override
  String get protectWithPin => 'Protect the app with a PIN';

  @override
  String get protectWithPinBody =>
      'Your finances stay private even if someone else picks up your phone.';

  @override
  String get setPin => 'Set a PIN';

  @override
  String get later => 'Later';

  @override
  String get pinIsSet => 'PIN set';

  @override
  String get autoRatesOnboardingTitle => 'Update exchange rates automatically';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeColour => 'Choose a colour';

  @override
  String get wallpaperColour => 'Wallpaper colours';

  @override
  String get wallpaperColourBody =>
      'Uses colours from your Android 12+ wallpaper';

  @override
  String get wallpaperColourActive => 'Wallpaper colours are on';

  @override
  String get preview => 'Preview';

  @override
  String seedSelected(String name) {
    return '$name, selected';
  }

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get ratesSection => 'Exchange rates';

  @override
  String get autoRatesShort => 'Update automatically';

  @override
  String get autoRatesSource => 'Source: CBAR (cbar.az)';

  @override
  String get ratesUpdating => 'Updating…';

  @override
  String get ratesUpdatingShort => 'Updating';

  @override
  String ratesLastUpdatedShort(String when) {
    return 'Last updated: $when';
  }

  @override
  String get ratesStaleSuffix => '(stale)';

  @override
  String ratesOfflineSince(String when) {
    return 'Offline. Last rates: $when';
  }

  @override
  String get ratesNotUpdated => 'Not updated';

  @override
  String ratesNotUpdatedSince(String date) {
    return 'Not updated. Last rates: $date';
  }

  @override
  String get ratesNeverFetchedOffline =>
      'Not downloaded yet. Manually entered rates are used.';

  @override
  String get retry => 'Try again';

  @override
  String get ratesUnitHeader => '1 unit = ? AZN';

  @override
  String get manualOverrideNote =>
      'A rate you enter by hand isn\'t changed by automatic updates.';

  @override
  String get resetToCbar => 'Back to the CBAR rate';

  @override
  String holdingsShareOfNetWorth(int percent) {
    return '$percent% of net worth';
  }

  @override
  String holdingsPlaceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count places',
      one: '1 place',
    );
    return '$_temp0';
  }

  @override
  String holdingsZeroGroup(int count) {
    return 'Zero balance ($count)';
  }

  @override
  String get updatedToday => 'updated today';

  @override
  String updatedDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'updated $days days ago',
      one: 'updated 1 day ago',
    );
    return '$_temp0';
  }

  @override
  String holdingDeleteConfirm(String name) {
    return 'Delete “$name”?';
  }

  @override
  String holdingCurrentAmount(String amount) {
    return 'now $amount';
  }

  @override
  String holdingNewBalance(String amount) {
    return 'New balance: $amount';
  }

  @override
  String holdingDifference(String amount) {
    return 'Difference: $amount';
  }

  @override
  String get withdrawTooMuch => 'You can\'t take out more than the balance';

  @override
  String get linkFromAccount => 'Take from an account';

  @override
  String get linkToAccount => 'Put into an account';

  @override
  String get holdingUpdateValue => 'Update value';

  @override
  String get holdingValueShort => 'Value';

  @override
  String get estimatedInterest => 'Est. interest';

  @override
  String get range3m => '3M';

  @override
  String get range6m => '6M';

  @override
  String get range1y => '1Y';

  @override
  String get chartNeedsTwoPoints => 'The chart needs at least 2 entries';

  @override
  String get holdingAdded => 'Added';

  @override
  String get holdingWithdrawn => 'Withdrawn';

  @override
  String get holdingValueSet => 'Value updated';

  @override
  String holdingBefore(String amount) {
    return 'was $amount';
  }

  @override
  String fromAccountName(String name) {
    return 'from $name';
  }

  @override
  String toAccountName(String name) {
    return 'to $name';
  }

  @override
  String get holdingNameHintPerson => 'e.g. With mum';

  @override
  String get holdingNameHintDeposit => 'e.g. Kapital 12 months';

  @override
  String get holdingNameHintGold => 'e.g. Gold ring';

  @override
  String get holdingFromAccount => 'Move the amount from an account';

  @override
  String get holdingCurrencyLockedHelper =>
      'The currency is fixed because there is history';

  @override
  String get maturityAfterToday => 'The maturity date must be after today';

  @override
  String get holdingMoveChip => 'Holding';

  @override
  String get rateJumpTitle => 'Big exchange rate change';

  @override
  String get rateJumpBody =>
      'These CBAR rates differ from the previous ones by more than 50%. Apply them?';

  @override
  String get rateJumpKeep => 'Keep previous';

  @override
  String get rateJumpApply => 'Apply';
}
