import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../../../data/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/settings_controller.dart';
import '../../settings/transport_fares_screen.dart' show showOwnRouteSheet;

/// Route code badge: >= 40 × 28, radius 8, secondaryContainer; own routes
/// get an outline border (DESIGN.md §18.5.3).
class RouteBadge extends StatelessWidget {
  const RouteBadge({super.key, required this.code, this.custom = false});

  final String code;
  final bool custom;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 40, minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: AppRadius.brSm,
        border: custom ? Border.all(color: cs.outline) : null,
      ),
      // Sized to the code (never to the parent), centred in the minimum box.
      child: Align(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          code,
          style: theme.textTheme.labelLarge?.copyWith(color: cs.onSecondaryContainer).merge(AppTextStyles.tabular),
        ),
      ),
    );
  }
}

/// Bus route picker (90 % height): search, recent routes, all routes in
/// natural order, and "Öz marşrutumu əlavə et". Pops the chosen code.
class BusRouteSheet extends ConsumerStatefulWidget {
  const BusRouteSheet({super.key, this.selected});

  final String? selected;

  @override
  ConsumerState<BusRouteSheet> createState() => _BusRouteSheetState();
}

class _BusRouteSheetState extends ConsumerState<BusRouteSheet> {
  String _query = '';

  Widget _row(BuildContext context, BusRoute r, String lang) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final Color variant = theme.colorScheme.onSurfaceVariant;
    return ListTile(
      minTileHeight: 56,
      leading: RouteBadge(code: r.code, custom: r.isCustom),
      title: Text(r.label.isEmpty ? r.code : r.label, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: r.uncertain
          ? Text(l.fareUncertain, style: theme.textTheme.bodySmall?.copyWith(color: variant))
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (r.isCustom)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: Text(l.myRoute, style: theme.textTheme.labelSmall),
            ),
          Text(
            Fmt.money(r.fare, Currency.azn.code, lang),
            style: theme.textTheme.bodySmall?.copyWith(color: variant).merge(AppTextStyles.tabular),
          ),
          if (r.code == widget.selected) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.check)),
        ],
      ),
      onTap: () => Navigator.of(context).pop(r.code),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final ThemeData theme = Theme.of(context);
    final ResolvedFares? fares = ref.watch(resolvedFaresProvider).value;
    final List<String> recentCodes = ref.watch(recentRoutesProvider(TransportMode.bus)).value ?? const <String>[];
    final List<BusRoute> results = fares?.search(_query) ?? const <BusRoute>[];
    final List<BusRoute> recent = _query.trim().isNotEmpty || fares == null
        ? const <BusRoute>[]
        : <BusRoute>[for (final String c in recentCodes) ?fares.busRoute(c)];
    TextStyle? header = theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary);

    final Widget add = ListTile(
      leading: const Icon(Icons.add),
      title: Text(l.addOwnRoute),
      onTap: () async {
        final String? code = await showOwnRouteSheet(context, ref, initialCode: _query.trim());
        if (code != null && context.mounted) Navigator.of(context).pop(code);
      },
    );

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.9,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
              child: SearchBar(
                autoFocus: true,
                hintText: l.searchRoutes,
                leading: const Icon(Icons.search),
                onChanged: (String v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: fares == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      children: <Widget>[
                        if (recent.isNotEmpty) ...<Widget>[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                            child: Text(l.recentRoutes.toUpperCase(), style: header),
                          ),
                          for (final BusRoute r in recent) _row(context, r, lang),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                            child: Text(l.allRoutes.toUpperCase(), style: header),
                          ),
                        ],
                        if (results.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Text(l.noRouteFound, style: theme.textTheme.bodyLarge),
                          ),
                        for (final BusRoute r in results) _row(context, r, lang),
                        add,
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Metro station picker grouped by line (DESIGN.md §18.5.3). Pops the
/// station name, or '' for "no station".
class MetroStationSheet extends ConsumerWidget {
  const MetroStationSheet({super.key, this.selected});

  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final ThemeData theme = Theme.of(context);
    final TransportCatalog? catalog = ref.watch(transportCatalogProvider).value;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.9,
      child: catalog == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: <Widget>[
                ListTile(
                  title: Text(l.metroStation),
                  trailing: selected == null ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.of(context).pop(''),
                ),
                for (final MetroLine line in catalog.metroLines) ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
                    child: Row(
                      children: <Widget>[
                        _LineDot(style: MetroLineStyle.of(line.id)),
                        const SizedBox(width: AppSpacing.sm),
                        Text(line.name(lang), style: theme.textTheme.titleSmall),
                      ],
                    ),
                  ),
                  for (final String s in line.stations)
                    ListTile(
                      title: Text(s),
                      trailing: s == selected ? const Icon(Icons.check) : null,
                      onTap: () => Navigator.of(context).pop(s),
                    ),
                ],
              ],
            ),
    );
  }
}

class _LineDot extends StatelessWidget {
  const _LineDot({required this.style});

  final MetroLineStyle style;

  @override
  Widget build(BuildContext context) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: style.ring ? null : style.color,
          border: style.ring ? Border.all(color: style.color, width: 2) : null,
        ),
      );
}
