import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/prefs.dart';

@immutable
class AppSettings {
  const AppSettings({
    this.languageCode = 'az',
    this.themeMode = ThemeMode.system,
    this.hideBalance = false,
    this.notificationsEnabled = true,
    this.blockScreenshots = true,
    this.seedId = 'teal',
    this.useDynamicColor = false,
  });

  final String languageCode;
  final ThemeMode themeMode;
  final bool hideBalance;

  /// Budget alerts as system notifications (the SnackBar always shows).
  final bool notificationsEnabled;

  /// FLAG_SECURE on the whole app (default on).
  final bool blockScreenshots;

  /// `AppSeed.id` of the chosen theme colour preset.
  final String seedId;

  /// Use the Android 12+ wallpaper colours when available.
  final bool useDynamicColor;

  Locale get locale => Locale(languageCode);

  AppSettings copyWith({
    String? languageCode,
    ThemeMode? themeMode,
    bool? hideBalance,
    bool? notificationsEnabled,
    bool? blockScreenshots,
    String? seedId,
    bool? useDynamicColor,
  }) =>
      AppSettings(
        languageCode: languageCode ?? this.languageCode,
        themeMode: themeMode ?? this.themeMode,
        hideBalance: hideBalance ?? this.hideBalance,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        blockScreenshots: blockScreenshots ?? this.blockScreenshots,
        seedId: seedId ?? this.seedId,
        useDynamicColor: useDynamicColor ?? this.useDynamicColor,
      );
}

class SettingsController extends Notifier<AppSettings> {
  static const List<String> supportedLanguages = <String>['az', 'en'];

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() {
    final SharedPreferences p = ref.watch(sharedPreferencesProvider);
    final String lang = p.getString(PrefKeys.language) ?? 'az';
    final String theme = p.getString(PrefKeys.themeMode) ?? 'system';
    return AppSettings(
      languageCode: supportedLanguages.contains(lang) ? lang : 'az',
      themeMode: ThemeMode.values.firstWhere(
        (ThemeMode m) => m.name == theme,
        orElse: () => ThemeMode.system,
      ),
      hideBalance: p.getBool(PrefKeys.hideBalance) ?? false,
      notificationsEnabled: p.getBool(PrefKeys.notificationsEnabled) ?? true,
      blockScreenshots: p.getBool(PrefKeys.blockScreenshots) ?? true,
      seedId: p.getString(PrefKeys.seedId) ?? 'teal',
      useDynamicColor: p.getBool(PrefKeys.useDynamicColor) ?? false,
    );
  }

  Future<void> setLanguage(String code) async {
    state = state.copyWith(languageCode: code);
    await _prefs.setString(PrefKeys.language, code);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString(PrefKeys.themeMode, mode.name);
  }

  Future<void> setNotificationsEnabled(bool on) async {
    state = state.copyWith(notificationsEnabled: on);
    await _prefs.setBool(PrefKeys.notificationsEnabled, on);
  }

  Future<void> setSeedId(String id) async {
    state = state.copyWith(seedId: id);
    await _prefs.setString(PrefKeys.seedId, id);
  }

  Future<void> setUseDynamicColor(bool on) async {
    state = state.copyWith(useDynamicColor: on);
    await _prefs.setBool(PrefKeys.useDynamicColor, on);
  }

  Future<void> setBlockScreenshots(bool on) async {
    state = state.copyWith(blockScreenshots: on);
    await _prefs.setBool(PrefKeys.blockScreenshots, on);
  }

  /// True once the runtime notification permission has been requested.
  bool get notificationPermissionAsked =>
      _prefs.getBool(PrefKeys.notificationPermissionAsked) ?? false;

  Future<void> markNotificationPermissionAsked() =>
      _prefs.setBool(PrefKeys.notificationPermissionAsked, true);

  Future<void> toggleHideBalance() async {
    state = state.copyWith(hideBalance: !state.hideBalance);
    await _prefs.setBool(PrefKeys.hideBalance, state.hideBalance);
  }
}

final NotifierProvider<SettingsController, AppSettings> settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

/// Current UI language code ('az' / 'en').
final Provider<String> languageProvider = Provider<String>(
  (Ref ref) => ref.watch(settingsProvider).languageCode,
);
