import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../lock/lock_back_interceptor.dart';
import '../lock/lock_controller.dart';
import '../lock/pin_flow_screen.dart';
import '../settings/rate_sync_controller.dart';
import '../settings/settings_controller.dart';
import 'onboarding_controller.dart';
import 'onboarding_illustrations.dart';

/// First launch (DESIGN.md §15): 3 intro pages, then Dil → Valyuta → PIN →
/// Avtomatik məzənnə → app.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  static const int introPages = 3;
  static const int setupPages = 4;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pages = PageController();
  int _page = 0;
  bool _languageChosen = false;
  bool _autoRates = false;
  bool _finishing = false;

  int get _total => OnboardingScreen.introPages + OnboardingScreen.setupPages;

  @override
  void initState() {
    super.initState();
    // System / predictive back goes to the previous page; on page 1 the app
    // goes to the background (LockBackInterceptor).
    LockBackInterceptor.overlayBack = () {
      if (_page == 0) return false;
      _go(_page - 1);
      return true;
    };
  }

  @override
  void dispose() {
    LockBackInterceptor.overlayBack = null;
    _pages.dispose();
    super.dispose();
  }

  void _go(int page) {
    if (!_pages.hasClients) return;
    if (AppMotion.reduced(context)) {
      _pages.jumpToPage(page);
    } else {
      _pages.animateToPage(
        page,
        duration: AppMotion.onboardingPage,
        curve: AppMotion.emphasized,
      );
    }
  }

  void _next() => _go((_page + 1).clamp(0, _total - 1));

  /// "Keç" on a setup step: defaults (device language if az/en, PIN off,
  /// auto rates off), then finish.
  Future<void> _skipAll() async {
    if (!_languageChosen) {
      final String device =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      await ref
          .read(settingsProvider.notifier)
          .setLanguage(
            SettingsController.supportedLanguages.contains(device)
                ? device
                : 'az',
          );
    }
    await _finish(autoRates: false);
  }

  Future<void> _finish({required bool autoRates}) async {
    if (_finishing) return;
    _finishing = true;
    AppHaptics.confirm();
    if (autoRates) {
      // The first fetch runs in the background; it never blocks entry.
      unawaited(ref.read(rateSyncProvider.notifier).setEnabled(true));
    }
    await ref.read(onboardingProvider.notifier).finish();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool intro = _page < OnboardingScreen.introPages;
    final int step = _page - OnboardingScreen.introPages; // 0..3 on setup pages

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 56,
              child: Row(
                children: <Widget>[
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: intro
                        ? const SizedBox.shrink()
                        : StepBar(
                            step: step,
                            count: OnboardingScreen.setupPages,
                          ),
                  ),
                  TextButton(
                    onPressed: intro
                        ? () => _go(OnboardingScreen.introPages)
                        : _skipAll,
                    child: Text(l.onboardingSkip),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (int p) => setState(() => _page = p),
                children: <Widget>[
                  _IntroPage(
                    illustration: const LedgerIllustration(),
                    title: l.onb1Title,
                    body: l.onb1Body,
                    page: 0,
                    onNext: _next,
                  ),
                  _IntroPage(
                    illustration: const BudgetIllustration(),
                    title: l.onb2Title,
                    body: l.onb2Body,
                    page: 1,
                    onNext: _next,
                  ),
                  _IntroPage(
                    illustration: const NetWorthIllustration(),
                    title: l.onb3Title,
                    body: l.onb3Body,
                    page: 2,
                    onNext: _next,
                  ),
                  _LanguagePage(
                    onChosen: () => _languageChosen = true,
                    onNext: _next,
                  ),
                  _CurrencyPage(onNext: _next),
                  _PinPage(onNext: _next),
                  _RatesPage(
                    value: _autoRates,
                    onChanged: (bool v) => setState(() => _autoRates = v),
                    onStart: () => _finish(autoRates: _autoRates),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 4 segments, 4dp high, plus "2 / 4".
class StepBar extends StatelessWidget {
  const StepBar({super.key, required this.step, required this.count});

  final int step;
  final int count;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Semantics(
      label: '${step + 1} / $count',
      excludeSemantics: true,
      child: Row(
        children: <Widget>[
          for (int i = 0; i < count; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: AnimatedContainer(
                duration: AppMotion.of(context, AppMotion.state),
                height: 4,
                decoration: BoxDecoration(
                  color: i <= step ? cs.primary : cs.surfaceContainerHighest,
                  borderRadius: AppRadius.brXs,
                ),
              ),
            ),
          ],
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${step + 1} / $count',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

/// Page dots: 8dp, the active one a 24×8 primary pill.
class OnboardingDots extends StatelessWidget {
  const OnboardingDots({super.key, required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Semantics(
      label: l.onboardingPageOf(index + 1, count),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < count; i++)
            AnimatedContainer(
              duration: AppMotion.of(context, AppMotion.state),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == index
                  ? AppSizes.onboardingDotActive
                  : AppSizes.onboardingDot,
              height: AppSizes.onboardingDot,
              decoration: BoxDecoration(
                color: i == index
                    ? cs.primary
                    : cs.onSurfaceVariant.withValues(alpha: 0.38),
                borderRadius: AppRadius.brFull,
              ),
            ),
        ],
      ),
    );
  }
}

class _PageBody extends StatelessWidget {
  const _PageBody({required this.content, required this.bottom});

  final List<Widget> content;
  final List<Widget> bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(children: content),
              ),
            ),
          ),
          ...bottom,
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

Widget _fullWidth(Widget button) =>
    SizedBox(width: double.infinity, child: button);

class _IntroPage extends StatelessWidget {
  const _IntroPage({
    required this.illustration,
    required this.title,
    required this.body,
    required this.page,
    required this.onNext,
  });

  final Widget illustration;
  final String title;
  final String body;
  final int page;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    return _PageBody(
      content: <Widget>[
        const SizedBox(height: AppSpacing.xl),
        illustration,
        const SizedBox(height: AppSpacing.xl),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTextStyles.onboardingTitle.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          body,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
      bottom: <Widget>[
        OnboardingDots(index: page, count: OnboardingScreen.introPages),
        const SizedBox(height: AppSpacing.lg),
        _fullWidth(
          FilledButton(onPressed: onNext, child: Text(l.onboardingNext)),
        ),
      ],
    );
  }
}

class _LanguagePage extends ConsumerWidget {
  const _LanguagePage({required this.onChosen, required this.onNext});

  final VoidCallback onChosen;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String current = ref.watch(languageProvider);
    Widget option(String code, String flag, String label) => ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: ListTile(
        leading: Text(flag, style: const TextStyle(fontSize: 24)),
        title: Text(label),
        trailing: Icon(
          code == current
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
        ),
        selected: code == current,
        onTap: () {
          AppHaptics.key();
          onChosen();
          ref.read(settingsProvider.notifier).setLanguage(code);
        },
      ),
    );
    return _PageBody(
      content: <Widget>[
        const SizedBox(height: AppSpacing.lg),
        AnimatedSwitcher(
          duration: AppMotion.of(context, AppMotion.fadeThroughDuration),
          transitionBuilder: AppMotion.fadeThrough,
          child: Text(
            l.chooseLanguage,
            key: ValueKey<String>(current),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        option('az', '🇦🇿', 'Azərbaycan dili'),
        option('en', '🇬🇧', 'English'),
      ],
      bottom: <Widget>[
        _fullWidth(
          FilledButton(onPressed: onNext, child: Text(l.onboardingNext)),
        ),
      ],
    );
  }
}

class _CurrencyPage extends StatelessWidget {
  const _CurrencyPage({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return _PageBody(
      content: <Widget>[
        const SizedBox(height: AppSpacing.lg),
        Text(l.baseCurrency, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.lg),
        Semantics(
          label: l.baseCurrencyAzn,
          excludeSemantics: true,
          child: Container(
            padding: AppSpacing.card,
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: AppRadius.brLg,
            ),
            child: Row(
              children: <Widget>[
                Text(
                  '₼',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: cs.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'AZN',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: cs.onSecondaryContainer,
                        ),
                      ),
                      Text(
                        l.aznName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.check, color: cs.onSecondaryContainer),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(l.baseCurrencyBody, style: theme.textTheme.bodyMedium),
      ],
      bottom: <Widget>[
        _fullWidth(
          FilledButton(onPressed: onNext, child: Text(l.onboardingNext)),
        ),
      ],
    );
  }
}

Widget _badge(BuildContext context, IconData icon) {
  final ColorScheme cs = Theme.of(context).colorScheme;
  return ExcludeSemantics(
    child: Container(
      width: AppSizes.emptyStateIconCircle,
      height: AppSizes.emptyStateIconCircle,
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 48, color: cs.onPrimaryContainer),
    ),
  );
}

class _PinPage extends ConsumerWidget {
  const _PinPage({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final bool done = ref.watch(
      lockControllerProvider.select((AppLockState s) => s.enabled),
    );

    Future<void> setUp() async {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (BuildContext ctx) => PinFlowScreen(
            mode: PinFlowMode.setup,
            onFinished: (bool ok) => Navigator.of(ctx).pop(ok),
          ),
        ),
      );
    }

    return _PageBody(
      content: <Widget>[
        const SizedBox(height: AppSpacing.xl),
        _badge(context, done ? Icons.lock : Icons.lock_outline),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l.protectWithPin,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l.protectWithPinBody,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        if (done) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.check_circle, color: AppColors.of(context).success),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l.pinIsSet,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.of(context).success,
                ),
              ),
            ],
          ),
        ],
      ],
      bottom: <Widget>[
        if (done)
          _fullWidth(
            FilledButton(onPressed: onNext, child: Text(l.onboardingNext)),
          )
        else ...<Widget>[
          _fullWidth(FilledButton(onPressed: setUp, child: Text(l.setPin))),
          const SizedBox(height: AppSpacing.sm),
          TextButton(onPressed: onNext, child: Text(l.later)),
        ],
      ],
    );
  }
}

class _RatesPage extends StatelessWidget {
  const _RatesPage({
    required this.value,
    required this.onChanged,
    required this.onStart,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    return _PageBody(
      content: <Widget>[
        const SizedBox(height: AppSpacing.xl),
        _badge(context, Icons.currency_exchange),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l.autoRatesOnboardingTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l.ratesPrivacyNote,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        SwitchListTile(
          title: Text(l.autoRates),
          value: value,
          onChanged: (bool v) {
            AppHaptics.key();
            onChanged(v);
          },
        ),
      ],
      bottom: <Widget>[
        _fullWidth(
          FilledButton(onPressed: onStart, child: Text(l.onboardingStart)),
        ),
      ],
    );
  }
}
