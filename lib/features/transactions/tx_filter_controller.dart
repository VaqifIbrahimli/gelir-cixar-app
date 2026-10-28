import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';

/// Filter state of the Transactions tab.
class TxFilterController extends Notifier<TxFilter> {
  @override
  TxFilter build() => const TxFilter();

  void setTypes(List<TxType> types) {
    // Category belongs to one type; drop it if the type no longer matches.
    state = state.copyWith(types: types, categoryId: () => null);
  }

  void setAccount(int? id) => state = state.copyWith(accountId: () => id);

  void setCategory(int? id) => state = state.copyWith(categoryId: () => id);

  void setWindow(DateWindow? w) => state = state.copyWith(window: () => w);

  void setQuery(String q) => state = state.copyWith(query: q);

  /// Replaces the whole filter (e.g. drill-down from Reports).
  void apply(TxFilter f) => state = f;

  void reset() => state = const TxFilter();
}

final NotifierProvider<TxFilterController, TxFilter> txFilterProvider =
    NotifierProvider<TxFilterController, TxFilter>(TxFilterController.new);
