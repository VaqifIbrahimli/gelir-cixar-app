import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import 'lock_controller.dart';
import 'pin_flow_screen.dart';

enum _Phase { checking, deviceCredential, insecure, newPin }

/// Shown by [LockScreen] when the lock was configured but secure storage no
/// longer holds the PIN (wiped, or reset by flutter_secure_storage's
/// resetOnError). Without this the app would open unlocked.
///
/// * Device with a screen lock: the phone's own credential (PIN, pattern or
///   biometric; local_auth with biometricOnly: false), then a new PIN.
/// * Device without a screen lock: there is nothing to re-authenticate
///   against. After an explicit warning the user may set a new PIN. This
///   trades protection for availability on purpose: refusing would lock the
///   owner out of their own data forever, while anyone holding such a phone
///   can already open every other app on it. The warning says so.
class LockRecoveryView extends ConsumerStatefulWidget {
  const LockRecoveryView({super.key});

  @override
  ConsumerState<LockRecoveryView> createState() => _LockRecoveryViewState();
}

class _LockRecoveryViewState extends ConsumerState<LockRecoveryView> {
  _Phase _phase = _Phase.checking;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.read(lockControllerProvider.notifier).isDeviceSecure().then((bool? secure) {
      if (!mounted) return;
      // Unknown: try the device credential; local_auth reports a missing one.
      setState(() => _phase = secure == false ? _Phase.insecure : _Phase.deviceCredential);
    });
  }

  Future<void> _confirmWithDevice() async {
    if (_busy) return;
    _busy = true;
    final AppLocalizations l = AppLocalizations.of(context);
    final DeviceAuthResult r = await ref
        .read(lockControllerProvider.notifier)
        .recoverWithDeviceCredential(l.lockRecoveryReason);
    _busy = false;
    if (!mounted) return;
    setState(() {
      switch (r) {
        case DeviceAuthResult.success:
          _phase = _Phase.newPin;
          _error = null;
        case DeviceAuthResult.notSecure:
          _phase = _Phase.insecure;
          _error = null;
        case DeviceAuthResult.failed:
          _error = l.lockRecoveryAuthFailed;
      }
    });
  }

  Future<void> _restoreInsecure() async {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: Text(l.lockRecoveryWarningTitle),
        content: Text(l.lockRecoveryWarningBody),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.lockRecoveryWarningConfirm),
          ),
        ],
      ),
    );
    if (!(ok ?? false) || !mounted) return;
    final bool allowed = await ref.read(lockControllerProvider.notifier).authorizeInsecureRecovery();
    if (!mounted) return;
    // A screen lock was set up meanwhile: use it instead.
    setState(() => _phase = allowed ? _Phase.newPin : _Phase.deviceCredential);
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.newPin) {
      // setPin unlocks the app; the cover then goes away.
      return PinFlowScreen(mode: PinFlowMode.setup, canCancel: false, onFinished: (_) {});
    }
    final AppLocalizations l = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xxxl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: cs.errorContainer, borderRadius: AppRadius.brLg),
                  child: Icon(Icons.lock_reset, size: 32, color: cs.onErrorContainer),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(l.lockRecoveryTitle,
                    style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                if (_phase != _Phase.checking)
                  Text(
                    _phase == _Phase.insecure ? l.lockRecoveryInsecureBody : l.lockRecoveryBody,
                    style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Text(_error!,
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                      textAlign: TextAlign.center),
                ],
                const SizedBox(height: AppSpacing.xl),
                switch (_phase) {
                  _Phase.checking => const SizedBox.shrink(),
                  _Phase.deviceCredential => FilledButton.icon(
                      icon: const Icon(Icons.verified_user_outlined),
                      label: Text(l.lockRecoveryConfirmButton),
                      onPressed: _confirmWithDevice,
                    ),
                  _Phase.insecure => OutlinedButton.icon(
                      icon: const Icon(Icons.lock_open),
                      label: Text(l.lockRecoveryRestoreButton),
                      onPressed: _restoreInsecure,
                    ),
                  _Phase.newPin => const SizedBox.shrink(),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}
