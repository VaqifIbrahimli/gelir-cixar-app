import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// App name / version from the platform (pubspec `version`).
final FutureProvider<PackageInfo> packageInfoProvider =
    FutureProvider<PackageInfo>((Ref ref) => PackageInfo.fromPlatform());

/// "1.0.0" (or "?" while loading / unavailable).
final Provider<String> appVersionProvider = Provider<String>(
  (Ref ref) => ref.watch(packageInfoProvider).value?.version ?? '?',
);
