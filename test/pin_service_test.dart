// PIN service, tested only through its public API so the hashing and
// storage layout can change freely. Secure storage is the plugin's own
// in-memory test platform (FlutterSecureStorage.setMockInitialValues); time
// is driven through the injectable uptime clock, never by sleeping.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelir_cixar/features/lock/pin_service.dart';

/// Monotonic clock the test advances by hand.
class FakeUptime {
  int ms = 1000000;
  bool available = true;

  Future<int?> call() async => available ? ms : null;

  void advance(Duration d) => ms += d.inMilliseconds;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> store;
  late FakeUptime clock;
  late PinService pins;

  // Low PBKDF2 cost keeps the suite fast; the iteration count is part of the
  // public constructor, the hash format is not asserted anywhere.
  PinService makeService() => PinService(null, 1000, clock.call);

  setUp(() {
    store = <String, String>{};
    FlutterSecureStorage.setMockInitialValues(store);
    clock = FakeUptime();
    pins = makeService();
  });

  Future<PinCheck> failUntilLocked(String wrong) async {
    PinCheck r;
    int guard = 0;
    do {
      r = await pins.verify(wrong);
      expect(++guard, lessThanOrEqualTo(PinService.freeAttempts));
    } while (r.lockedUntil == null);
    return r;
  }

  int secondsLeft(DateTime until) =>
      (until.difference(DateTime.now()).inMilliseconds / 1000).round();

  group('set / verify', () {
    test('no PIN until one is set; length is remembered', () async {
      expect(await pins.hasPin(), isFalse);
      await pins.setPin('123456');
      expect(await pins.hasPin(), isTrue);
      expect(await pins.pinLength(), 6);
    });

    test('the plain PIN is never stored', () async {
      await pins.setPin('483920');
      expect(store.values.any((String v) => v.contains('483920')), isFalse);
    });

    test('the right PIN verifies, a wrong one does not', () async {
      await pins.setPin('1234');
      expect((await pins.verify('1234')).ok, isTrue);
      final PinCheck wrong = await pins.verify('4321');
      expect(wrong.ok, isFalse);
      expect(wrong.failedAttempts, 1);
      expect(wrong.lockedUntil, isNull);
      expect((await pins.verify('12345')).ok, isFalse, reason: 'longer input');
      expect((await pins.verify('123')).ok, isFalse, reason: 'prefix');
      expect((await pins.verify('')).ok, isFalse);
    });

    test('a successful check resets the failure counter', () async {
      await pins.setPin('1234');
      await pins.verify('0000');
      await pins.verify('0000');
      expect((await pins.verify('1234')).ok, isTrue);
      expect((await pins.verify('0000')).failedAttempts, 1);
    });

    test('changing the PIN invalidates the old one', () async {
      await pins.setPin('1234');
      await pins.setPin('5678');
      expect((await pins.verify('1234')).ok, isFalse);
      expect((await pins.verify('5678')).ok, isTrue);
    });

    test('the same PIN set twice is salted differently', () async {
      await pins.setPin('1234');
      final Map<String, String> first = Map<String, String>.of(store);
      await pins.setPin('1234');
      expect(store, isNot(equals(first)));
      expect((await pins.verify('1234')).ok, isTrue);
    });

    test('setPin rejects anything but 4-6 digits and keeps the old PIN', () async {
      await pins.setPin('1234');
      for (final String bad in <String>['123', '1234567', '12a4', '', '12 34', '١٢٣٤']) {
        await expectLater(pins.setPin(bad), throwsArgumentError, reason: '"$bad"');
      }
      expect((await pins.verify('1234')).ok, isTrue);
    });

    test('clearPin removes the PIN', () async {
      await pins.setPin('1234');
      await pins.clearPin();
      expect(await pins.hasPin(), isFalse);
      expect((await pins.verify('1234')).ok, isFalse);
    });

    test('the PIN is persisted, not kept in memory', () async {
      await pins.setPin('2468');
      expect((await makeService().verify('2468')).ok, isTrue);
    });

    test('a PIN created with the default cost verifies', () async {
      final PinService prod = PinService(null, PinService.defaultIterations, clock.call);
      await prod.setPin('9753');
      expect((await prod.verify('9753')).ok, isTrue);
    });
  });

  group('lockout', () {
    test('four wrong attempts are free; the fifth locks for 30 s', () async {
      await pins.setPin('1234');
      for (int i = 1; i < PinService.freeAttempts; i++) {
        final PinCheck r = await pins.verify('0000');
        expect(r.failedAttempts, i);
        expect(r.lockedUntil, isNull, reason: 'attempt $i');
      }
      final PinCheck fifth = await pins.verify('0000');
      expect(fifth.ok, isFalse);
      expect(fifth.failedAttempts, 5);
      expect(secondsLeft(fifth.lockedUntil!), 30);
      expect(await pins.lockedUntil(), isNotNull);
    });

    test('while locked even the right PIN is refused, without counting', () async {
      await pins.setPin('1234');
      final PinCheck locked = await failUntilLocked('0000');
      final PinCheck r = await pins.verify('1234');
      expect(r.ok, isFalse);
      expect(r.lockedUntil, isNotNull);
      expect(r.failedAttempts, locked.failedAttempts);
    });

    test('the lockout ends exactly when its time has passed', () async {
      await pins.setPin('1234');
      await failUntilLocked('0000');
      clock.advance(const Duration(seconds: 29));
      expect(await pins.lockedUntil(), isNotNull);
      clock.advance(const Duration(seconds: 1));
      expect(await pins.lockedUntil(), isNull);
      expect((await pins.verify('1234')).ok, isTrue);
    });

    test('lockouts grow progressively: 30 s, 60 s, 120 s, 240 s', () async {
      await pins.setPin('1234');
      final List<int> seconds = <int>[];
      PinCheck r = await failUntilLocked('0000');
      seconds.add(secondsLeft(r.lockedUntil!));
      for (int i = 0; i < 3; i++) {
        clock.advance(Duration(seconds: seconds.last));
        expect(await pins.lockedUntil(), isNull);
        r = await pins.verify('0000');
        expect(r.lockedUntil, isNotNull, reason: 'every failure after the 5th locks');
        seconds.add(secondsLeft(r.lockedUntil!));
      }
      expect(seconds, <int>[30, 60, 120, 240]);
    });

    test('the right PIN after a lockout resets the counter and the schedule', () async {
      await pins.setPin('1234');
      await failUntilLocked('0000');
      clock.advance(const Duration(minutes: 1));
      expect((await pins.verify('1234')).ok, isTrue);
      expect(await pins.lockedUntil(), isNull);
      final PinCheck next = await pins.verify('0000');
      expect(next.failedAttempts, 1);
      expect(next.lockedUntil, isNull);
    });

    test('lockout survives a new service instance', () async {
      await pins.setPin('2468');
      await failUntilLocked('0000');
      final PinService fresh = makeService();
      expect(await fresh.lockedUntil(), isNotNull);
      expect((await fresh.verify('2468')).ok, isFalse);
    });

    test('an unreadable clock keeps the lockout (fails closed)', () async {
      await pins.setPin('1234');
      await failUntilLocked('0000');
      clock.advance(const Duration(hours: 2));
      clock.available = false;
      expect(await pins.lockedUntil(), isNotNull);
      expect((await pins.verify('1234')).ok, isFalse);
    });

    test('a reboot (uptime back near zero) never shortens the lockout', () async {
      await pins.setPin('1234');
      await failUntilLocked('0000');
      clock.ms = 10000; // rebooted 10 s ago, earlier than the lockout start
      expect(await pins.lockedUntil(), isNotNull);
      clock.ms = 30000;
      expect(await pins.lockedUntil(), isNull);
    });

    test('schedule doubles from 30 s and is capped at one hour', () {
      expect(PinService.lockoutFor(5), const Duration(seconds: 30));
      expect(PinService.lockoutFor(6), const Duration(seconds: 60));
      expect(PinService.lockoutFor(7), const Duration(seconds: 120));
      expect(PinService.lockoutFor(10), const Duration(seconds: 960));
      expect(PinService.lockoutFor(12), const Duration(hours: 1));
      expect(PinService.lockoutFor(1000), const Duration(hours: 1));
    });
  });

  group('without an uptime clock (wall-clock fallback)', () {
    test('the default service still locks after five failures', () async {
      final PinService fallback = PinService();
      await fallback.setPin('1234');
      PinCheck r = const PinCheck.success();
      for (int i = 0; i < PinService.freeAttempts; i++) {
        r = await fallback.verify('0000');
      }
      expect(r.lockedUntil, isNotNull);
      // Real wall clock here: a slow run can already be a second into the lock.
      expect(secondsLeft(r.lockedUntil!), inInclusiveRange(28, 30));
      expect((await fallback.verify('1234')).ok, isFalse);
    });
  });
}
