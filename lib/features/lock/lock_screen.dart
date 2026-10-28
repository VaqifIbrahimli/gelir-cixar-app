import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import 'lock_controller.dart';
import 'pin_service.dart';
import 'widgets/pin_pad.dart';

/// Shared header for lock / PIN screens: app mark, name and prompt.
class LockHeader extends StatelessWidget {
  const LockHeader({super.key, required this.prompt, this.message, this.isError = false});

  final String prompt;
  final String? message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: AppRadius.brLg,
          ),
          child: Icon(Icons.lock_outline, size: 32, color: cs.onPrimaryContainer),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(l.appTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(prompt, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
        SizedBox(
          height: 40,
          child: message == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isError ? cs.error : cs.onSurfaceVariant,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Mixin with the lockout countdown used by every PIN entry screen.
mixin LockoutCountdown<T extends StatefulWidget> on State<T> {
  DateTime? lockedUntil;
  Timer? _ticker;

  int get secondsLeft {
    final DateTime? u = lockedUntil;
    if (u == null) return 0;
    final int s = (u.difference(DateTime.now()).inMilliseconds / 1000).ceil();
    return s < 0 ? 0 : s;
  }

  bool get isLockedOut => secondsLeft > 0;

  void startLockout(DateTime? until) {
    _ticker?.cancel();
    setState(() => lockedUntil = until);
    if (until == null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) return t.cancel();
      if (!isLockedOut) {
        t.cancel();
        setState(() => lockedUntil = null);
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

/// Unlock screen shown over the app while [LockStatus.locked].
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen>
    with LockoutCountdown<LockScreen> {
  final GlobalKey<PinPadState> _pad = GlobalKey<PinPadState>();
  String? _message;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final LockController c = ref.read(lockControllerProvider.notifier);
      final DateTime? until = await c.lockedUntil();
      if (!mounted) return;
      if (until != null) startLockout(until);
      if (ref.read(lockControllerProvider).biometricEnabled && until == null) {
        _biometric();
      }
    });
  }

  Future<void> _biometric() async {
    final AppLocalizations l = AppLocalizations.of(context);
    await ref.read(lockControllerProvider.notifier).unlockWithBiometrics(l.biometricReason);
  }

  Future<void> _submit(String pin) async {
    if (_busy) return;
    _busy = true;
    final AppLocalizations l = AppLocalizations.of(context);
    final PinCheck r =
        await ref.read(lockControllerProvider.notifier).unlockWithPin(pin);
    _busy = false;
    if (r.ok) AppHaptics.confirm();
    if (!mounted || r.ok) return;
    await _pad.currentState?.showError();
    if (!mounted) return;
    if (r.lockedUntil != null) {
      startLockout(r.lockedUntil);
      setState(() => _message = null);
    } else {
      final int left = PinService.freeAttempts - r.failedAttempts;
      setState(() => _message = l.wrongPinAttemptsLeft(left));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AppLockState lock = ref.watch(lockControllerProvider);
    final bool locked = isLockedOut;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                LockHeader(
                  prompt: l.enterPin,
                  message: locked ? l.lockedOutFor(secondsLeft) : _message,
                  isError: locked || _message != null,
                ),
                const SizedBox(height: AppSpacing.lg),
                PinPad(
                  key: _pad,
                  length: lock.pinLength,
                  enabled: !locked,
                  onCompleted: _submit,
                  onBiometric: lock.biometricEnabled ? _biometric : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
