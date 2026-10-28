import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/enums.dart';
import '../features/accounts/account_edit_screen.dart';
import '../features/accounts/accounts_screen.dart';
import '../features/budgets/budgets_screen.dart';
import '../features/categories/categories_screen.dart';
import '../features/categories/category_edit_screen.dart';
import '../features/export/export_screen.dart';
import '../features/holdings/holding_detail_screen.dart';
import '../features/holdings/holding_edit_screen.dart';
import '../features/holdings/holdings_screen.dart';
import '../features/home/home_screen.dart';
import '../features/lock/pin_flow_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/settings/appearance_screen.dart';
import '../features/settings/exchange_rates_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/transactions/transaction_edit_screen.dart';
import '../features/transactions/transactions_screen.dart';
import 'theme.dart';

/// Route paths. Tabs are shell branches; everything else is pushed on the
/// root navigator so it covers the bottom bar.
abstract final class Routes {
  static const String home = '/';
  static const String transactions = '/transactions';
  static const String reports = '/reports';
  static const String budgets = '/budgets';
  static const String settings = '/settings';

  static const String rates = '/rates';
  static const String appearance = '/appearance';
  static const String export = '/export';

  static const String holdings = '/holdings';
  static const String newHolding = '/holdings/new';
  static String holding(int id) => '/holdings/$id';
  static String editHolding(int id) => '/holdings/$id/edit';

  static const String accounts = '/accounts';
  static const String newAccount = '/accounts/new';
  static String editAccount(int id) => '/accounts/$id';

  static const String categories = '/categories';
  static String newCategory(CategoryType type) =>
      '/categories/new?type=${type.name}';
  static String editCategory(int id) => '/categories/$id';

  static String newTransaction([TxType type = TxType.expense]) =>
      '/transaction/new?type=${type.name}';
  static String editTransaction(int id) => '/transaction/$id';

  /// Returns `true` via `pop` when the flow completed.
  static String pin(PinFlowMode mode) => '/pin/${mode.name}';
}

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.home,
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (BuildContext context, GoRouterState state,
                StatefulNavigationShell shell) =>
            AppShell(navigationShell: shell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
              path: Routes.home,
              builder: (_, _) => const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
              path: Routes.transactions,
              builder: (_, _) => const TransactionsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
              path: Routes.reports,
              builder: (_, _) => const ReportsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
              path: Routes.budgets,
              builder: (_, _) => const BudgetsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
              path: Routes.settings,
              builder: (_, _) => const SettingsScreen(),
            ),
          ]),
        ],
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/transaction/new',
        pageBuilder: (BuildContext context, GoRouterState state) {
          final TxType type = TxType.values.firstWhere(
            (TxType t) => t.name == state.uri.queryParameters['type'],
            orElse: () => TxType.expense,
          );
          return _slideUp(
            context,
            state,
            TransactionEditScreen(initialType: type),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/transaction/:id',
        pageBuilder: (BuildContext context, GoRouterState state) => _slideUp(
          context,
          state,
          TransactionEditScreen(
            transactionId: int.tryParse(state.pathParameters['id'] ?? ''),
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.accounts,
        builder: (_, _) => const AccountsScreen(),
        routes: <RouteBase>[
          GoRoute(
            parentNavigatorKey: rootNavigatorKey,
            path: 'new',
            builder: (_, _) => const AccountEditScreen(),
          ),
          GoRoute(
            parentNavigatorKey: rootNavigatorKey,
            path: ':id',
            builder: (BuildContext context, GoRouterState state) =>
                AccountEditScreen(
              accountId: int.tryParse(state.pathParameters['id'] ?? ''),
            ),
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.categories,
        builder: (_, _) => const CategoriesScreen(),
        routes: <RouteBase>[
          GoRoute(
            parentNavigatorKey: rootNavigatorKey,
            path: 'new',
            builder: (BuildContext context, GoRouterState state) =>
                CategoryEditScreen(
              initialType: state.uri.queryParameters['type'] ==
                      CategoryType.income.name
                  ? CategoryType.income
                  : CategoryType.expense,
            ),
          ),
          GoRoute(
            parentNavigatorKey: rootNavigatorKey,
            path: ':id',
            builder: (BuildContext context, GoRouterState state) =>
                CategoryEditScreen(
              categoryId: int.tryParse(state.pathParameters['id'] ?? ''),
            ),
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.holdings,
        builder: (_, _) => const HoldingsScreen(),
        routes: <RouteBase>[
          GoRoute(
            parentNavigatorKey: rootNavigatorKey,
            path: 'new',
            builder: (_, _) => const HoldingEditScreen(),
          ),
          GoRoute(
            parentNavigatorKey: rootNavigatorKey,
            path: ':id',
            builder: (BuildContext context, GoRouterState state) => HoldingDetailScreen(
              holdingId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
            ),
            routes: <RouteBase>[
              GoRoute(
                parentNavigatorKey: rootNavigatorKey,
                path: 'edit',
                builder: (BuildContext context, GoRouterState state) => HoldingEditScreen(
                  holdingId: int.tryParse(state.pathParameters['id'] ?? ''),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.appearance,
        builder: (_, _) => const AppearanceScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.rates,
        builder: (_, _) => const ExchangeRatesScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.export,
        builder: (_, _) => const ExportScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/pin/:mode',
        builder: (BuildContext context, GoRouterState state) => PinFlowScreen(
          mode: PinFlowMode.values.firstWhere(
            (PinFlowMode m) => m.name == state.pathParameters['mode'],
            orElse: () => PinFlowMode.verify,
          ),
          onFinished: (bool ok) => context.pop(ok),
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// Full-screen slide-up transition for the add/edit transaction route.
CustomTransitionPage<void> _slideUp(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    fullscreenDialog: true,
    transitionDuration: AppDurations.of(context, AppDurations.normal),
    reverseTransitionDuration: AppDurations.of(context, AppDurations.normal),
    child: child,
    transitionsBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondary,
      Widget child,
    ) =>
        SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      )),
      child: child,
    ),
  );
}
