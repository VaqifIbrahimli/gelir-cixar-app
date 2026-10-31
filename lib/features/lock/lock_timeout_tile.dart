import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import 'lock_controller.dart';
import 'pin_flow_screen.dart';

/// Localised label of a [LockTimeout].
String lockTimeoutLabel(AppLocalizations l, LockTimeout t) {
  final Duration d = t.duration;
  if (d == Duration.zero) return l.lockTimeoutImmediately;
  if (d.inMinutes == 0) return l.lockTimeoutSeconds(d.inSeconds);
  if (d.inHours == 0) return l.lockTimeoutMinutes(d.inMinutes);
  return l.lockTimeoutHours(d.inHours);
}

/// Settings → Kilid row for the auto-lock delay. Opens a bottom sheet with
/// the choices; a change needs the PIN (or biometrics when enabled), like
/// turning the lock off. Disabled while the app lock is off.
///
/// ```dart
/// const LockTimeoutTile(),
/// ```
class LockTimeoutTile extends ConsumerWidget {
  const LockTimeoutTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AppLockState lock = ref.watch(lockControllerProvider);
    return ListTile(
      leading: const Icon(Icons.timer_outlined),
      title: Text(l.lockTimeoutTitle),
      subtitle: Text(lockTimeoutLabel(l, lock.timeout)),
      enabled: lock.enabled,
      onTap: () => _change(context, ref, lock.timeout),
    );
  }

  Future<void> _change(BuildContext context, WidgetRef ref, LockTimeout current) async {
    final LockTimeout? picked = await showModalBottomSheet<LockTimeout>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) => _TimeoutSheet(current: current),
    );
    if (picked == null || picked == current || !context.mounted) return;
    if (!await _reauthenticate(context, ref) || !context.mounted) return;
    await ref.read(lockControllerProvider.notifier).setTimeout(picked);
  }

  /// Biometrics when enabled (tripwire checked), else / on failure the PIN.
  static Future<bool> _reauthenticate(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l = AppLocalizations.of(context);
    final LockController c = ref.read(lockControllerProvider.notifier);
    final NavigatorState nav = Navigator.of(context, rootNavigator: true);
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
    if (ref.read(lockControllerProvider).biometricEnabled) {
      if (await c.reauthenticateWithBiometrics(l.lockTimeoutReauthReason)) return true;
      if (ref.read(lockControllerProvider).biometricEnrollmentChanged) {
        messenger?.showSnackBar(SnackBar(content: Text(l.lockBiometricEnrollmentChanged)));
      }
    }
    final bool? ok = await nav.push<bool>(MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (BuildContext ctx) => PinFlowScreen(
        mode: PinFlowMode.verify,
        onFinished: (bool ok) => Navigator.of(ctx).pop(ok),
      ),
    ));
    return ok ?? false;
  }
}

class _TimeoutSheet extends StatelessWidget {
  const _TimeoutSheet({required this.current});

  final LockTimeout current;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        child: RadioGroup<LockTimeout>(
          groupValue: current,
          onChanged: (LockTimeout? t) => Navigator.of(context).pop(t),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l.lockTimeoutTitle, style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l.lockTimeoutHint,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              for (final LockTimeout t in LockTimeout.values)
                RadioListTile<LockTimeout>(
                  value: t,
                  title: Text(lockTimeoutLabel(l, t)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
