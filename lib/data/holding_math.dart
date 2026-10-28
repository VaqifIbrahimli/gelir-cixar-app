import 'database.dart';

/// Thrown when a change would make a holding's amount negative at some
/// point in its history, or an entry amount is out of range.
class HoldingAmountException implements Exception {
  const HoldingAmountException(this.reason);

  final HoldingAmountFailure reason;

  @override
  String toString() => 'HoldingAmountException($reason)';
}

enum HoldingAmountFailure { negative, invalidAmount, currencyLocked, notFound }

/// One point of a holding's value history.
typedef HoldingPoint = ({DateTime date, int amount});

/// Replays holding entries. Order is date, then id, so two entries on the
/// same day apply in the order they were recorded.
abstract final class HoldingMath {
  /// Largest single amount (matches the transaction amount keypad).
  static const int maxAmount = 999999999999;

  /// Id used for an entry that is not stored yet, so it sorts after stored
  /// entries of the same date.
  static const int pendingId = 1 << 52;

  static int _compare(HoldingEntry a, HoldingEntry b) {
    final int byDate = a.date.compareTo(b.date);
    return byDate != 0 ? byDate : a.id.compareTo(b.id);
  }

  static List<HoldingEntry> sorted(Iterable<HoldingEntry> entries) =>
      entries.toList()..sort(_compare);

  /// Amount after each entry, in replay order. Throws
  /// [HoldingAmountException] if any step would go below zero or an amount is
  /// out of range.
  static List<HoldingPoint> replay(Iterable<HoldingEntry> entries) {
    int value = 0;
    final List<HoldingPoint> out = <HoldingPoint>[];
    for (final HoldingEntry e in sorted(entries)) {
      checkAmount(e.kind, e.amount);
      value = switch (e.kind) {
        HoldingEntryKind.setValue => e.amount,
        HoldingEntryKind.add => value + e.amount,
        HoldingEntryKind.withdraw => value - e.amount,
      };
      if (value < 0) throw const HoldingAmountException(HoldingAmountFailure.negative);
      if (value > maxAmount) throw const HoldingAmountException(HoldingAmountFailure.invalidAmount);
      out.add((date: e.date, amount: value));
    }
    return out;
  }

  /// Current amount (0 with no entries).
  static int current(Iterable<HoldingEntry> entries) {
    final List<HoldingPoint> r = replay(entries);
    return r.isEmpty ? 0 : r.last.amount;
  }

  /// Same as [current] but tolerant: a broken history yields null instead of
  /// throwing (used for display).
  static int? tryCurrent(Iterable<HoldingEntry> entries) {
    try {
      return current(entries);
    } on HoldingAmountException {
      return null;
    }
  }

  /// add / withdraw need a positive amount; setValue may be 0.
  static void checkAmount(HoldingEntryKind kind, int amount) {
    final bool ok = kind == HoldingEntryKind.setValue
        ? amount >= 0 && amount <= maxAmount
        : amount > 0 && amount <= maxAmount;
    if (!ok) throw const HoldingAmountException(HoldingAmountFailure.invalidAmount);
  }
}
