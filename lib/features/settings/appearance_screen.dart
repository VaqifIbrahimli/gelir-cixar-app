import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' as mui;

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/enums.dart';
import '../../l10n/app_localizations.dart';
import 'settings_controller.dart';

/// Settings → Görünüş (DESIGN.md §12.1).
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AppSettings s = ref.watch(settingsProvider);
    final SettingsController ctl = ref.read(settingsProvider.notifier);
    final ThemeData theme = Theme.of(context);
    final Brightness b = theme.brightness;

    return Scaffold(
      appBar: AppBar(title: Text(l.appearance)),
      body: DynamicColorBuilder(
        builder: (mui.ColorScheme? light, mui.ColorScheme? dark) {
          // Wallpaper colours exist only on Android 12+.
          final bool available = light != null;
          final bool dynOn = available && s.useDynamicColor;
          final AppSeed seed = AppSeed.fromId(s.seedId);
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              Text(l.theme, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: <ButtonSegment<ThemeMode>>[
                  ButtonSegment<ThemeMode>(value: ThemeMode.system, label: Text(l.themeSystem)),
                  ButtonSegment<ThemeMode>(value: ThemeMode.light, label: Text(l.themeLight)),
                  ButtonSegment<ThemeMode>(value: ThemeMode.dark, label: Text(l.themeDark)),
                ],
                selected: <ThemeMode>{s.themeMode},
                onSelectionChanged: (Set<ThemeMode> v) {
                  AppHaptics.key();
                  ctl.setThemeMode(v.first);
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              if (available)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.wallpaperColour),
                  subtitle: Text(l.wallpaperColourBody),
                  value: s.useDynamicColor,
                  onChanged: (bool v) {
                    AppHaptics.key();
                    ctl.setUseDynamicColor(v);
                  },
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(l.themeColour, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.md),
              Opacity(
                opacity: dynOn ? 0.38 : 1,
                child: IgnorePointer(
                  ignoring: dynOn,
                  child: Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: <Widget>[
                      for (final AppSeed x in AppSeed.values)
                        _SeedSwatch(
                          seed: x,
                          brightness: b,
                          selected: x == seed,
                          label: x.label(s.languageCode),
                          onTap: () {
                            AppHaptics.key();
                            ctl.setSeedId(x.id);
                          },
                        ),
                    ],
                  ),
                ),
              ),
              if (dynOn)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    l.wallpaperColourActive,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
              Text(l.preview, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              _Preview(lang: s.languageCode),
            ],
          );
        },
      ),
    );
  }
}

/// 48dp swatch with a 3dp onSurface ring and ✓ when selected.
class _SeedSwatch extends StatelessWidget {
  const _SeedSwatch({
    required this.seed,
    required this.brightness,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final AppSeed seed;
  final Brightness brightness;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final ColorScheme swatch = AppTheme.scheme(Brightness.light, seed: seed);
    return Semantics(
      button: true,
      selected: selected,
      label: selected ? l.seedSelected(label) : label,
      excludeSemantics: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedContainer(
              duration: AppMotion.of(context, AppMotion.state),
              width: AppSizes.seedSwatch + 12,
              height: AppSizes.seedSwatch + 12,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? cs.onSurface : Colors.transparent, width: 3),
              ),
              child: Container(
                decoration: BoxDecoration(color: swatch.primary, shape: BoxShape.circle),
                child: selected ? Icon(Icons.check, color: swatch.onPrimary) : null,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

/// Mini balance card, a transaction line and a button in the live theme.
class _Preview extends StatelessWidget {
  const _Preview({required this.lang});

  final String lang;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final AppColors c = AppColors.of(context);
    return Container(
      padding: AppSpacing.card,
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: AppRadius.brLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: AppSpacing.card,
            decoration: BoxDecoration(gradient: c.balanceGradient, borderRadius: AppRadius.brLg),
            child: Wrap(
              spacing: AppSpacing.md,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(Fmt.base(321075, lang), style: AppTextStyles.amountSecondary.copyWith(color: c.onBalanceCard)),
                Text(Fmt.signed(25000, 'AZN', TxType.income, lang), style: TextStyle(color: c.balanceIncome)),
                Text(Fmt.signed(1840, 'AZN', TxType.expense, lang), style: TextStyle(color: c.balanceExpense)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(child: Text(l.txTypeExpense, style: theme.textTheme.titleMedium)),
              Text(
                Fmt.signed(1840, 'AZN', TxType.expense, lang),
                style: AppTextStyles.amountTile.copyWith(color: c.expense),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(alignment: Alignment.centerLeft, child: FilledButton(onPressed: () {}, child: Text(l.save))),
        ],
      ),
    );
  }
}
