import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import 'lock_controller.dart';
import 'lock_screen.dart';
import 'pin_service.dart';
import 'widgets/pin_pad.dart';

/// What the PIN flow does.
enum PinFlowMode {
  /// Create a PIN (enter twice) and turn the lock on.
  setup,

  /// Verify the current PIN, then create a new one.
  change,

  /// Verify the current PIN only (e.g. before turning the lock off).
  verify,
}

enum _Step { current, create, confirm }

/// PIN creation / change / verification. Calls [onFinished] with true on
/// success, false when cancelled.
class PinFlowScreen extends ConsumerStatefulWidget {
  const PinFlowScreen({
    super.key,
    required this.mode,
    required this.onFinished,
    this.canCancel = true,
  });

  final PinFlowMode mode;
  final ValueChanged<bool> onFinished;
  final bool canCancel;

  @override
  ConsumerState<PinFlowScreen> createState() => _PinFlowScreenState();
}

class _PinFlowScreenState extends ConsumerState<PinFlowScreen>
    with LockoutCountdown<PinFlowScreen> {
  late _Step _step =
      widget.mode == PinFlowMode.setup ? _Step.create : _Step.current;
  String _first = '';
  String? _message;
  bool _busy = false;
  // A new key per step resets the pad.
  GlobalKey<PinPadState> _pad = GlobalKey<PinPadState>();

  @override
  void initState() {
    super.initState();
    if (_step == _Step.current) {
      ref.read(lockControllerProvider.notifier).lockedUntil().then((DateTime? u) {
        if (mounted && u != null) startLockout(u);
      });
    }
  }

  void _go(_Step s, {String? message}) => setState(() {
        _step = s;
        _message = message;
        _pad = GlobalKey<PinPadState>();
      });

  Future<void> _onPin(String pin) async {
    if (_busy) return;
    final AppLocalizations l = AppLocalizations.of(context);
    final LockController c = ref.read(lockControllerProvider.notifier);
    switch (_step) {
      case _Step.current:
        _busy = true;
        final PinCheck r = await c.verifyPin(pin);
        _busy = false;
        if (!mounted) return;
        if (r.ok) {
          if (widget.mode == PinFlowMode.verify) {
            widget.onFinished(true);
          } else {
            _go(_Step.create);
          }
          return;
        }
        await _pad.currentState?.showError();
        if (!mounted) return;
        if (r.lockedUntil != null) {
          startLockout(r.lockedUntil);
          setState(() => _message = null);
        } else {
          setState(() => _message = l.wrongPinAttemptsLeft(
                PinService.freeAttempts - r.failedAttempts,
              ));
        }
      case _Step.create:
        _first = pin;
        _go(_Step.confirm);
      case _Step.confirm:
        if (pin != _first) {
          await _pad.currentState?.showError();
          if (!mounted) return;
          _first = '';
          _go(_Step.create, message: l.pinMismatch);
          return;
        }
        _busy = true;
        await c.setPin(pin);
        _busy = false;
        if (mounted) widget.onFinished(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final int pinLength = ref.watch(lockControllerProvider).pinLength;
    final String prompt = switch (_step) {
      _Step.current => l.enterCurrentPin,
      _Step.create => l.createPin,
      _Step.confirm => l.confirmPin,
    };
    final bool locked = _step == _Step.current && isLockedOut;
    final String? message = locked
        ? l.lockedOutFor(secondsLeft)
        : _message ?? (_step == _Step.create ? l.pinLengthHint : null);

    return PopScope(
      canPop: widget.canCancel,
      child: Scaffold(
        appBar: widget.canCancel
            ? AppBar(
                leading: IconButton(
                  tooltip: l.cancel,
                  icon: const Icon(Icons.close),
                  onPressed: () => widget.onFinished(false),
                ),
              )
            : null,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (!widget.canCancel && widget.mode == PinFlowMode.setup)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        0,
                        AppSpacing.xl,
                        AppSpacing.lg,
                      ),
                      child: Text(
                        l.pinSetupIntro,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  LockHeader(
                    prompt: prompt,
                    message: message,
                    isError: locked || _message != null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PinPad(
                    key: _pad,
                    // Verification knows the stored length; creation is 4–6.
                    length: _step == _Step.current
                        ? pinLength
                        : _step == _Step.confirm
                            ? _first.length
                            : null,
                    minLength: PinService.minLength,
                    maxLength: PinService.maxLength,
                    enabled: !locked,
                    onCompleted: _onPin,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
