import 'package:drift/drift.dart';

import '../database.dart';

class CategoryRepository {
  CategoryRepository(this._db);

  final AppDatabase _db;

  Stream<List<TxCategory>> watch({
    CategoryType? type,
    bool includeArchived = false,
  }) {
    final SimpleSelectStatement<$CategoriesTable, TxCategory> q =
        _db.select(_db.categories)
          ..orderBy(<OrderClauseGenerator<$CategoriesTable>>[
            (c) => OrderingTerm.asc(c.isArchived),
            (c) => OrderingTerm.asc(c.sortOrder),
            (c) => OrderingTerm.asc(c.id),
          ]);
    if (type != null) q.where((c) => c.type.equalsValue(type));
    if (!includeArchived) q.where((c) => c.isArchived.equals(false));
    return q.watch();
  }

  /// Number of transactions per category id.
  Stream<Map<int, int>> watchUsageCounts() {
    final Expression<int> n = _db.transactions.id.count();
    final JoinedSelectStatement<$TransactionsTable, MoneyTx> q =
        _db.selectOnly(_db.transactions)
          ..addColumns(<Expression<Object>>[_db.transactions.categoryId, n])
          ..where(_db.transactions.categoryId.isNotNull())
          ..groupBy(<Expression<Object>>[_db.transactions.categoryId]);
    return q.watch().map(
          (List<TypedResult> rows) => <int, int>{
            for (final TypedResult r in rows)
              r.read(_db.transactions.categoryId)!: r.read(n) ?? 0,
          },
        );
  }

  Future<int> create({
    required String nameAz,
    required String nameEn,
    required int iconCodePoint,
    required int colorIndex,
    required CategoryType type,
    CategorySpecialKind specialKind = CategorySpecialKind.none,
  }) async {
    if (specialKind == CategorySpecialKind.bonusLoss) {
      throw ArgumentError('the bonus-loss category is a seeded system category');
    }
    final Expression<int> maxOrder = _db.categories.sortOrder.max();
    final TypedResult row = await (_db.selectOnly(_db.categories)
          ..addColumns(<Expression<Object>>[maxOrder]))
        .getSingle();
    return _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            nameAz: nameAz,
            nameEn: nameEn,
            iconCodePoint: iconCodePoint,
            colorIndex: Value(colorIndex),
            type: type,
            sortOrder: Value((row.read(maxOrder) ?? 0) + 1),
            specialKind: Value(type == CategoryType.expense ? specialKind : CategorySpecialKind.none),
          ),
        );
  }

  /// Saves edits. The system category keeps its kind, type and is never
  /// archived; no other category can become the system one, and only
  /// expense categories can be transport.
  Future<void> update(TxCategory c) => _db.transaction(() async {
        final TxCategory? old = await byId(c.id);
        if (old == null) return;
        TxCategory next = c;
        if (old.specialKind == CategorySpecialKind.bonusLoss) {
          next = c.copyWith(
            specialKind: CategorySpecialKind.bonusLoss,
            type: CategoryType.expense,
            isArchived: false,
          );
        } else if (c.specialKind == CategorySpecialKind.bonusLoss ||
            (c.specialKind == CategorySpecialKind.transport && c.type != CategoryType.expense)) {
          next = c.copyWith(specialKind: CategorySpecialKind.none);
        }
        await _db.update(_db.categories).replace(next);
      });

  Future<TxCategory?> byId(int id) =>
      (_db.select(_db.categories)..where((c) => c.id.equals(id))).getSingleOrNull();

  /// Thrown by [setArchived] / [deleteOrArchive] for the system category.
  static bool _isSystem(TxCategory? c) => c?.specialKind == CategorySpecialKind.bonusLoss;

  Future<void> setArchived(int id, bool archived) => _db.transaction(() async {
        if (archived && _isSystem(await byId(id))) {
          throw StateError('the system category cannot be archived');
        }
        await (_db.update(_db.categories)..where((c) => c.id.equals(id)))
            .write(CategoriesCompanion(isArchived: Value(archived)));
      });

  Future<bool> isUsed(int id) async {
    final Expression<int> n = _db.transactions.id.count();
    final TypedResult row = await (_db.selectOnly(_db.transactions)
          ..addColumns(<Expression<Object>>[n])
          ..where(_db.transactions.categoryId.equals(id)))
        .getSingle();
    final Expression<int> b = _db.budgets.id.count();
    final TypedResult brow = await (_db.selectOnly(_db.budgets)
          ..addColumns(<Expression<Object>>[b])
          ..where(_db.budgets.categoryId.equals(id)))
        .getSingle();
    return (row.read(n) ?? 0) > 0 || (brow.read(b) ?? 0) > 0;
  }

  /// Hard-deletes an unused category; otherwise archives it.
  /// Returns true when the row was really deleted.
  Future<bool> deleteOrArchive(int id) => _db.transaction(() async {
        if (_isSystem(await byId(id))) {
          throw StateError('the system category cannot be deleted');
        }
        if (await isUsed(id)) {
          await setArchived(id, true);
          return false;
        }
        await (_db.delete(_db.categories)..where((c) => c.id.equals(id)))
            .go();
        return true;
      });
}
