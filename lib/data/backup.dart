import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;

import '../core/theme.dart' show AppCardDesigns;
import 'card_images.dart';
import 'database.dart';
import 'holding_math.dart';
import 'models.dart' show BudgetThresholds;
import 'repositories/transport_fare_repository.dart';

/// Thrown when a backup file cannot be restored. [reason] is a stable code
/// the UI maps to a localised message.
class BackupException implements Exception {
  const BackupException(this.reason, [this.detail]);

  final BackupFailure reason;
  final Object? detail;

  @override
  String toString() => 'BackupException($reason, $detail)';
}

enum BackupFailure { notJson, wrongFormat, newerSchema, invalidData, tooLarge }

/// A finished export: the JSON text, and how many card photos were left
/// out because they are larger than [CardImageStore.maxBytes].
class BackupExport {
  const BackupExport(this.json, {this.skippedImages = 0});

  final String json;
  final int skippedImages;
}

/// Full JSON backup of every table, and an all-or-nothing restore.
///
/// File shape:
/// ```json
/// { "format": "gelir_cixar_backup", "schemaVersion": 3, "appVersion": "1.0.0",
///   "createdAt": "...", "tables": { "accounts": [...], ... } }
/// ```
/// Rows use drift's JSON serialisation (camelCase keys, DateTime as epoch ms,
/// enums by name). Since schema 4 the root also has
/// `"cardImages": [{"name": "card_….jpg", "data": "<base64>"}]` with the
/// account card photos (each at most [CardImageStore.maxBytes]).
class BackupService {
  BackupService(this._db, {this.images});

  final AppDatabase _db;

  /// Where card photos live; null in tests that do not exercise them (then
  /// photos are neither exported nor written on restore).
  final CardImageStore? images;

  static const String format = 'gelir_cixar_backup';

  /// Largest backup file accepted (~150k transactions); bigger input is
  /// refused before it is read or parsed.
  static const int maxBytes = 32 * 1024 * 1024;

  /// Per-table row caps, far above real use, so a crafted file cannot make
  /// the restore run for minutes.
  static const Map<String, int> maxRows = <String, int>{
    'accounts': 1000,
    'categories': 1000,
    'transactions': 300000,
    'budgets': 100000,
    'exchangeRates': 100,
    'budgetAlerts': 300000,
    'holdings': 10000,
    'holdingEntries': 300000,
    'transportFares': 5000,
    'cardImages': 1000,
  };

  /// Trips per transaction, as the editor's stepper allows.
  static const int maxTrips = 20;

  /// Longest link group id accepted (the app writes 32 hex digits).
  static const int maxLinkIdLength = 64;

  /// Matches the amount keypad (10 integer digits, 2 decimals).
  static const int maxAmountMinor = 999999999999;

  /// Same limit as the note field in the transaction editor, with headroom.
  static const int maxNoteLength = 1000;

  /// Entries of the categorical palette (AppColors.categorical).
  static const int paletteSize = 12;

  Future<String> exportJson({required String appVersion}) async =>
      (await export(appVersion: appVersion)).json;

  /// Like [exportJson], and reports card photos that were too large.
  Future<BackupExport> export({required String appVersion}) async {
    final List<Account> accounts = await _db.select(_db.accounts).get();
    final List<Map<String, Object?>> files = <Map<String, Object?>>[];
    int skipped = 0;
    final List<Map<String, dynamic>> accountRows = <Map<String, dynamic>>[];
    for (final Account a in accounts) {
      Account row = a;
      final String? name = a.cardImagePath;
      if (name != null) {
        final Uint8List? bytes = await images?.read(name);
        if (bytes != null && bytes.length <= CardImageStore.maxBytes && CardImageStore.isImage(bytes)) {
          files.add(<String, Object?>{'name': name, 'data': base64Encode(bytes)});
        } else {
          // Missing, oversized or not an image: the account keeps its photo
          // design (shown with the fallback) but the file is not carried.
          if (bytes != null) skipped++;
          row = a.copyWith(cardImagePath: const Value<String?>(null));
        }
      }
      accountRows.add(row.toJson());
    }
    final Map<String, Object?> data = <String, Object?>{
      'format': format,
      'schemaVersion': _db.schemaVersion,
      'appVersion': appVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'tables': <String, Object?>{
        'accounts': accountRows,
        'categories':
            (await _db.select(_db.categories).get()).map((TxCategory r) => r.toJson()).toList(),
        'transactions':
            (await _db.select(_db.transactions).get()).map((MoneyTx r) => r.toJson()).toList(),
        'budgets': (await _db.select(_db.budgets).get()).map((Budget r) => r.toJson()).toList(),
        'exchangeRates': (await _db.select(_db.exchangeRates).get())
            .map((ExchangeRate r) => r.toJson())
            .toList(),
        'budgetAlerts': (await _db.select(_db.budgetAlerts).get())
            .map((BudgetAlert r) => r.toJson())
            .toList(),
        'holdings':
            (await _db.select(_db.holdings).get()).map((Holding r) => r.toJson()).toList(),
        'holdingEntries': (await _db.select(_db.holdingEntries).get())
            .map((HoldingEntry r) => r.toJson())
            .toList(),
        'transportFares': (await _db.select(_db.transportFares).get())
            .map((TransportFare r) => r.toJson())
            .toList(),
      },
      'cardImages': files,
    };
    return BackupExport(const JsonEncoder.withIndent(' ').convert(data), skippedImages: skipped);
  }

  /// Parses and validates [json] completely, then replaces all data inside a
  /// single transaction. Any failure leaves the current data untouched.
  Future<BackupSummary> restoreJson(String json) async {
    // UTF-16 length <= UTF-8 byte length, so this never rejects a file that
    // passed the byte check in the UI.
    if (json.length > maxBytes) throw const BackupException(BackupFailure.tooLarge);
    final _Parsed p = _parse(json);
    _validate(p);
    final CardImageStore? store = images;
    if (store != null) {
      try {
        for (final MapEntry<String, Uint8List> e in p.images.entries) {
          await store.write(e.key, e.value);
        }
      } catch (e) {
        await _cleanImages();
        throw BackupException(BackupFailure.invalidData, 'card image: $e');
      }
    }
    try {
      await _db.transaction(() async {
        await _db.delete(_db.budgetAlerts).go();
        await _db.delete(_db.budgets).go();
        await _db.delete(_db.holdingEntries).go();
        await _db.delete(_db.transactions).go();
        await _db.delete(_db.holdings).go();
        await _db.delete(_db.categories).go();
        await _db.delete(_db.accounts).go();
        await _db.delete(_db.exchangeRates).go();
        await _db.delete(_db.transportFares).go();
        await _db.batch((b) {
          b.insertAll(_db.accounts, p.accounts);
          b.insertAll(_db.categories, p.categories);
          b.insertAll(_db.holdings, p.holdings);
          b.insertAll(_db.transactions, p.transactions);
          b.insertAll(_db.holdingEntries, p.holdingEntries);
          b.insertAll(_db.budgets, p.budgets);
          b.insertAll(_db.exchangeRates, p.rates);
          b.insertAll(_db.budgetAlerts, p.alerts);
          b.insertAll(_db.transportFares, p.fares);
        });
        // A pre-v1.2 file has no bonus-loss system category.
        await _db.ensureBonusLossCategory();
      });
    } on BackupException {
      await _cleanImages();
      rethrow;
    } catch (e) {
      // Constraint violations (e.g. a transaction pointing at a missing
      // account) roll the transaction back.
      await _cleanImages();
      throw BackupException(BackupFailure.invalidData, e);
    }
    await _cleanImages();
    return BackupSummary(
      accounts: p.accounts.length,
      categories: p.categories.length,
      transactions: p.transactions.length,
    );
  }

  /// Deletes photo files no account references (after a restore, or a
  /// failed one that already wrote files).
  Future<void> _cleanImages() async {
    final CardImageStore? store = images;
    if (store == null) return;
    final Set<String> keep = <String>{
      for (final Account a in await _db.select(_db.accounts).get())
        if (a.cardImagePath != null) a.cardImagePath!,
    };
    await store.deleteExcept(keep);
  }

  _Parsed _parse(String json) {
    final Object? root;
    try {
      root = jsonDecode(json);
    } on FormatException catch (e) {
      throw BackupException(BackupFailure.notJson, e);
    }
    if (root is! Map<String, Object?> || root['format'] != format) {
      throw const BackupException(BackupFailure.wrongFormat);
    }
    final Object? version = root['schemaVersion'];
    if (version is! int || version < 1) {
      throw const BackupException(BackupFailure.wrongFormat);
    }
    if (version > _db.schemaVersion) {
      throw BackupException(BackupFailure.newerSchema, version);
    }
    final Object? tables = root['tables'];
    if (tables is! Map<String, Object?>) {
      throw const BackupException(BackupFailure.wrongFormat);
    }

    List<T> rows<T>(
      String key,
      T Function(Map<String, dynamic>) fromJson, {
      bool optional = false,
      Map<String, dynamic> Function(Map<String, dynamic>)? upgrade,
    }) {
      final Object? list = tables[key];
      if (list == null && optional) return <T>[];
      if (list is! List<Object?>) {
        throw BackupException(BackupFailure.wrongFormat, key);
      }
      if (list.length > maxRows[key]!) {
        throw BackupException(BackupFailure.invalidData, '$key: too many rows');
      }
      try {
        return <T>[
          for (final Object? r in list)
            fromJson(upgrade == null
                ? r! as Map<String, dynamic>
                : upgrade(Map<String, dynamic>.of(r! as Map<String, dynamic>))),
        ];
      } catch (e) {
        throw BackupException(BackupFailure.invalidData, '$key: $e');
      }
    }

    final bool pre4 = version < 4;
    final List<TxCategory> categories = rows(
      'categories',
      TxCategory.fromJson,
      upgrade: pre4 ? _upgradeCategoryRow : null,
    );
    return _Parsed(
      accounts: rows('accounts', Account.fromJson, upgrade: pre4 ? _upgradeAccountRow : null),
      categories: pre4 ? _markTransport(categories) : categories,
      transactions: rows('transactions', MoneyTx.fromJson, upgrade: pre4 ? _upgradeTxRow : null),
      budgets: rows('budgets', Budget.fromJson),
      rates: rows(
        'exchangeRates',
        ExchangeRate.fromJson,
        upgrade: version < 3 ? _upgradeRateRow : null,
      ),
      // Absent in schema-1 backups.
      alerts: rows('budgetAlerts', BudgetAlert.fromJson, optional: true),
      // Absent before schema 3.
      holdings: rows('holdings', Holding.fromJson, optional: true),
      holdingEntries: rows('holdingEntries', HoldingEntry.fromJson, optional: true),
      // Absent before schema 4.
      fares: rows('transportFares', TransportFare.fromJson, optional: true),
      images: _parseImages(root['cardImages']),
    );
  }

  /// `cardImages`: names must be ours, data base64 of a JPEG / PNG of at
  /// most [CardImageStore.maxBytes] bytes.
  static Map<String, Uint8List> _parseImages(Object? list) {
    if (list == null) return const <String, Uint8List>{};
    if (list is! List<Object?>) throw const BackupException(BackupFailure.wrongFormat, 'cardImages');
    if (list.length > maxRows['cardImages']!) {
      throw const BackupException(BackupFailure.invalidData, 'cardImages: too many');
    }
    // base64 grows 4/3; anything longer cannot decode to <= maxBytes.
    const int maxEncoded = (CardImageStore.maxBytes + 2) ~/ 3 * 4;
    final Map<String, Uint8List> out = <String, Uint8List>{};
    for (final Object? r in list) {
      if (r is! Map<String, Object?>) throw const BackupException(BackupFailure.wrongFormat, 'cardImages');
      final Object? name = r['name'];
      final Object? data = r['data'];
      if (name is! String || !CardImageStore.isValidName(name) || out.containsKey(name)) {
        throw const BackupException(BackupFailure.invalidData, 'card image name');
      }
      if (data is! String || data.length > maxEncoded) {
        throw const BackupException(BackupFailure.invalidData, 'card image too large');
      }
      final Uint8List bytes;
      try {
        bytes = base64Decode(data);
      } on FormatException {
        throw const BackupException(BackupFailure.invalidData, 'card image encoding');
      }
      if (bytes.length > CardImageStore.maxBytes) {
        throw const BackupException(BackupFailure.invalidData, 'card image too large');
      }
      if (!CardImageStore.isImage(bytes)) {
        throw const BackupException(BackupFailure.invalidData, 'card image is not JPEG/PNG');
      }
      out[name] = bytes;
    }
    return out;
  }

  /// Pre-v4 accounts: the card design their type gets on a v4 upgrade.
  static Map<String, dynamic> _upgradeAccountRow(Map<String, dynamic> r) => r
    ..putIfAbsent('cardDesignId', () => AppDatabase.defaultDesignByType[r['type']] ?? AppCardDesigns.defaultId)
    ..putIfAbsent('bonusRatePercent', () => 50);

  static Map<String, dynamic> _upgradeCategoryRow(Map<String, dynamic> r) =>
      r..putIfAbsent('specialKind', () => CategorySpecialKind.none.name);

  static Map<String, dynamic> _upgradeTxRow(Map<String, dynamic> r) => r..putIfAbsent('trips', () => 1);

  /// Same rule as the v3 to v4 migration: the seeded Nəqliyyat (by id,
  /// else by name) becomes the transport category.
  static List<TxCategory> _markTransport(List<TxCategory> list) {
    bool isCandidate(TxCategory c) => c.type == CategoryType.expense && c.specialKind == CategorySpecialKind.none;
    final TxCategory? pick = list
            .where((TxCategory c) =>
                isCandidate(c) && c.id == AppDatabase.transportSeedId && c.nameAz == AppDatabase.transportNameAz)
            .firstOrNull ??
        list.where((TxCategory c) => isCandidate(c) && c.nameAz == AppDatabase.transportNameAz).firstOrNull ??
        list.where((TxCategory c) => isCandidate(c) && c.id == AppDatabase.transportSeedId).firstOrNull;
    if (pick == null || list.any((TxCategory c) => c.specialKind == CategorySpecialKind.transport)) return list;
    return <TxCategory>[
      for (final TxCategory c in list) c.id == pick.id ? c.copyWith(specialKind: CategorySpecialKind.transport) : c,
    ];
  }

  /// Pre-v3 rate rows have only currency + rateToAzn. A value that differs
  /// from the seeded default was typed by the user, so it becomes a manual
  /// override (same rule as the v2 to v3 database migration).
  static Map<String, dynamic> _upgradeRateRow(Map<String, dynamic> r) {
    final Object? code = r['currency'];
    final Object? value = r['rateToAzn'];
    final bool manual = value is num && AppDatabase.defaultRates[code] != value.toDouble();
    return r
      ..putIfAbsent('isManual', () => manual)
      ..putIfAbsent('source', () => manual ? RateSource.manual.name : RateSource.seed.name);
  }

  /// Semantic checks drift's column constraints do not cover, so a restored
  /// file can only contain data the app itself could have written. Column
  /// lengths and NOT NULL are checked by drift on insert, and foreign keys by
  /// SQLite; both roll the whole restore back.
  static void _validate(_Parsed p) {
    Never bad(String what) => throw BackupException(BackupFailure.invalidData, what);
    bool amountOk(int v) => v > 0 && v <= maxAmountMinor;
    bool colorOk(int v) => v >= 0 && v < paletteSize;
    final RegExp month = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$');
    final Set<String> currencies = <String>{for (final Currency c in Currency.values) c.code};
    final DateTime minDate = DateTime(1900);
    final DateTime maxDate = DateTime(2200);
    bool dateOk(DateTime d) => !d.isBefore(minDate) && d.isBefore(maxDate);

    final Set<String> designIds = <String>{
      for (final d in AppCardDesigns.presets) d.id,
      AppCardDesigns.photoId,
    };
    final RegExp fourDigits = RegExp(r'^\d{4}$');
    final Map<int, String> accountCurrency = <int, String>{};
    final Map<int, AccountType> accountTypes = <int, AccountType>{};
    final Set<String> usedImages = <String>{};
    for (final Account a in p.accounts) {
      if (accountCurrency.containsKey(a.id)) bad('account id ${a.id} repeated');
      accountCurrency[a.id] = a.currency;
      accountTypes[a.id] = a.type;
      if (!currencies.contains(a.currency)) bad('account currency');
      if (a.initialBalance.abs() > maxAmountMinor) bad('account balance');
      if (!colorOk(a.colorIndex)) bad('account color');
      if (!designIds.contains(a.cardDesignId)) bad('account card design');
      if (a.cardLast4 != null && !fourDigits.hasMatch(a.cardLast4!)) bad('account card last4');
      if (a.bonusRatePercent < 1 || a.bonusRatePercent > 100) bad('account bonus rate');
      final String? image = a.cardImagePath;
      if (image != null) {
        // Every referenced photo travels in the file, once.
        if (!p.images.containsKey(image) || !usedImages.add(image)) bad('account card image');
      }
    }
    if (usedImages.length != p.images.length) bad('card image without account');

    final Map<int, CategoryType> categoryTypes = <int, CategoryType>{};
    int? bonusLossCategory;
    for (final TxCategory c in p.categories) {
      if (categoryTypes.containsKey(c.id)) bad('category id ${c.id} repeated');
      categoryTypes[c.id] = c.type;
      if (!colorOk(c.colorIndex)) bad('category color');
      if (c.iconCodePoint < 0 || c.iconCodePoint > 0x10FFFF) bad('category icon');
      if (c.specialKind != CategorySpecialKind.none && c.type != CategoryType.expense) {
        bad('special kind on an income category');
      }
      if (c.specialKind == CategorySpecialKind.bonusLoss) {
        if (bonusLossCategory != null) bad('two bonus-loss categories');
        if (c.isArchived) bad('archived system category');
        bonusLossCategory = c.id;
      }
    }

    final Set<int> accountIds = accountCurrency.keys.toSet();

    final Map<int, Holding> holdings = <int, Holding>{};
    for (final Holding h in p.holdings) {
      if (holdings.containsKey(h.id)) bad('holding id ${h.id} repeated');
      holdings[h.id] = h;
      if (!currencies.contains(h.currency)) bad('holding currency');
      if (!colorOk(h.colorIndex)) bad('holding color');
      if (h.note.length > maxNoteLength) bad('holding note');
      final double? rate = h.interestRate;
      if (rate != null && (!rate.isFinite || rate < 0 || rate > 100)) bad('holding interest');
      if (h.maturityDate != null && !dateOk(h.maturityDate!)) bad('holding maturity');
      if (h.placeType != HoldingPlace.bankDeposit && (rate != null || h.maturityDate != null)) {
        bad('deposit fields on ${h.placeType.name}');
      }
    }

    final Map<int, MoneyTx> moves = <int, MoneyTx>{};
    final Map<String, List<MoneyTx>> groups = <String, List<MoneyTx>>{};
    for (final MoneyTx t in p.transactions) {
      if (!amountOk(t.amount)) bad('transaction amount');
      if (!dateOk(t.date)) bad('transaction date');
      if (t.note.length > maxNoteLength) bad('transaction note');
      if (!accountIds.contains(t.accountId)) bad('transaction account');
      if (t.updatedAt != null && !dateOk(t.updatedAt!)) bad('transaction updatedAt');
      if (t.trips < 1 || t.trips > maxTrips) bad('transaction trips');
      final TransportMode? mode = t.transportMode;
      if (mode == null) {
        if (t.routeCode != null || t.trips != 1) bad('transport fields without a mode');
      } else {
        if (t.type != TxType.expense) bad('transport mode on ${t.type.name}');
        if (t.routeCode != null && mode != TransportMode.bus && mode != TransportMode.metro) {
          bad('route on ${mode.name}');
        }
      }
      final String? link = t.linkGroupId;
      if (link != null) {
        if (link.isEmpty || link.length > maxLinkIdLength) bad('link group id');
        groups.putIfAbsent(link, () => <MoneyTx>[]).add(t);
      }
      if (t.type.isHoldingMove) {
        final int? h = t.holdingId;
        if (h == null || !holdings.containsKey(h)) bad('move holding');
        if (t.toAccountId != null || t.categoryId != null) bad('move with account/category');
        // Same shape HoldingRepository.move writes: toAmount only (and
        // always) when the account and holding currencies differ.
        final bool sameCurrency = accountCurrency[t.accountId] == holdings[h]!.currency;
        if (sameCurrency ? t.toAmount != null : t.toAmount == null) bad('move currency');
        if (t.toAmount != null && !amountOk(t.toAmount!)) bad('move amount');
        if (moves.containsKey(t.id)) bad('transaction id ${t.id} repeated');
        moves[t.id] = t;
        continue;
      }
      if (t.holdingId != null) bad('holding on ${t.type.name}');
      if (t.type == TxType.transfer) {
        final int? to = t.toAccountId;
        if (to == null || to == t.accountId || !accountIds.contains(to)) {
          bad('transfer target');
        }
        if (t.categoryId != null) bad('transfer with category');
        if (t.toAmount != null && !amountOk(t.toAmount!)) bad('transfer amount');
      } else {
        if (t.toAccountId != null || t.toAmount != null) bad('transfer fields on ${t.type.name}');
        final int? cat = t.categoryId;
        if (cat != null && categoryTypes[cat] != t.type.categoryType) {
          bad('transaction category');
        }
      }
    }

    // A link group is exactly what saveBonusTransfer writes: a same-currency
    // transfer out of a bonus account plus a bonus-loss expense on it, dated
    // alike.
    for (final List<MoneyTx> g in groups.values) {
      if (g.length != 2) bad('link group size');
      final MoneyTx? transfer = g.where((MoneyTx t) => t.type == TxType.transfer).firstOrNull;
      final MoneyTx? loss = g.where((MoneyTx t) => t.type == TxType.expense).firstOrNull;
      if (transfer == null || loss == null) bad('link group types');
      if (transfer.accountId != loss.accountId) bad('link group accounts');
      if (accountTypes[transfer.accountId] != AccountType.bonus) bad('link group source');
      if (transfer.toAmount != null || accountCurrency[transfer.toAccountId] != accountCurrency[transfer.accountId]) {
        bad('link group currency');
      }
      if (loss.categoryId == null || loss.categoryId != bonusLossCategory) bad('link group loss category');
      if (loss.transportMode != null) bad('link group loss transport');
      if (transfer.date != loss.date) bad('link group dates');
    }

    final Set<int> budgetIds = <int>{};
    for (final Budget b in p.budgets) {
      if (!budgetIds.add(b.id)) bad('budget id ${b.id} repeated');
      if (!categoryTypes.containsKey(b.categoryId)) bad('budget category');
      if (b.categoryId == bonusLossCategory) bad('budget on the system category');
      if (!month.hasMatch(b.month)) bad('budget month');
      if (!amountOk(b.limitAmount)) bad('budget limit');
    }

    final Set<int> entryIds = <int>{};
    final Map<int, List<HoldingEntry>> byHolding = <int, List<HoldingEntry>>{};
    final Set<int> linkedMoves = <int>{};
    for (final HoldingEntry e in p.holdingEntries) {
      if (!entryIds.add(e.id)) bad('holding entry id ${e.id} repeated');
      if (!holdings.containsKey(e.holdingId)) bad('entry holding');
      if (!dateOk(e.date)) bad('entry date');
      if (e.note.length > maxNoteLength) bad('entry note');
      final int? txId = e.transactionId;
      if (txId != null) {
        final MoneyTx? m = moves[txId];
        if (m == null || m.holdingId != e.holdingId || !linkedMoves.add(txId)) bad('entry move');
        final HoldingEntryKind expected =
            m.type == TxType.toHolding ? HoldingEntryKind.add : HoldingEntryKind.withdraw;
        if (e.kind != expected) bad('entry move kind');
        // The entry must move exactly what the account side moved, on the
        // same day; otherwise a file could debit 1 ₼ and credit a fortune.
        if (e.amount != (m.toAmount ?? m.amount)) bad('entry move amount');
        if (e.date != m.date) bad('entry move date');
      }
      byHolding.putIfAbsent(e.holdingId, () => <HoldingEntry>[]).add(e);
    }
    if (linkedMoves.length != moves.length) bad('move without holding entry');
    for (final List<HoldingEntry> list in byHolding.values) {
      try {
        HoldingMath.replay(list);
      } on HoldingAmountException {
        bad('holding amount out of range');
      }
    }

    for (final ExchangeRate r in p.rates) {
      final double? auto = r.autoRate;
      if (auto != null && (!auto.isFinite || auto <= 0 || auto > 1e6)) bad('auto rate value');
      if (r.rateDate != null && !dateOk(r.rateDate!)) bad('rate date');
      if (!currencies.contains(r.currency) || r.currency == Currency.base.code) {
        bad('rate currency');
      }
      if (!r.rateToAzn.isFinite || r.rateToAzn <= 0 || r.rateToAzn > 1e6) bad('rate value');
    }

    final Set<String> fareKeys = <String>{};
    for (final TransportFare f in p.fares) {
      if (!fareKeys.add('${f.mode.name}/${f.code}')) bad('fare repeated');
      if (!TransportFareRepository.fareOk(f.fare)) bad('fare value');
      if (!dateOk(f.updatedAt)) bad('fare date');
      switch (f.mode) {
        case TransportMode.bus:
          if (!TransportFareRepository.codePattern.hasMatch(f.code)) bad('fare route code');
          if (f.isCustom && (f.fromName.trim().isEmpty || f.toName.trim().isEmpty)) bad('own route stops');
        case TransportMode.metro || TransportMode.train:
          if (f.code.isNotEmpty || f.isCustom || f.fromName.isNotEmpty || f.toName.isNotEmpty) {
            bad('${f.mode.name} fare row');
          }
        case TransportMode.taxi || TransportMode.fuel || TransportMode.parking || TransportMode.bakuCard:
          bad('fare for ${f.mode.name}');
      }
    }

    for (final BudgetAlert a in p.alerts) {
      if (!budgetIds.contains(a.budgetId)) bad('alert budget');
      if (!month.hasMatch(a.month)) bad('alert month');
      if (a.threshold != BudgetThresholds.warning && a.threshold != BudgetThresholds.danger) {
        bad('alert threshold');
      }
    }
  }
}

class BackupSummary {
  const BackupSummary({
    required this.accounts,
    required this.categories,
    required this.transactions,
  });

  final int accounts;
  final int categories;
  final int transactions;
}

class _Parsed {
  const _Parsed({
    required this.accounts,
    required this.categories,
    required this.transactions,
    required this.budgets,
    required this.rates,
    required this.alerts,
    required this.holdings,
    required this.holdingEntries,
    required this.fares,
    required this.images,
  });

  final List<Account> accounts;
  final List<TxCategory> categories;
  final List<MoneyTx> transactions;
  final List<Budget> budgets;
  final List<ExchangeRate> rates;
  final List<BudgetAlert> alerts;
  final List<Holding> holdings;
  final List<HoldingEntry> holdingEntries;
  final List<TransportFare> fares;

  /// File name -> validated JPEG / PNG bytes.
  final Map<String, Uint8List> images;
}
