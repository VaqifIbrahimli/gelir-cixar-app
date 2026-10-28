import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Short-lived files for the share sheet (exports, backups). They hold the
/// user's whole financial history in plain text, so they live only in the
/// app's private cache, are deleted right after sharing, and anything left
/// behind by a crash is purged on the next start.
abstract final class ShareFiles {
  static const String _dirName = 'share_out';

  /// Where share_plus copies files before handing them to the target app,
  /// and where file_picker copies picked files. Both are private cache dirs.
  static const List<String> _pluginCaches = <String>['share_plus', 'file_picker'];

  static Future<Directory> _dir() async {
    final Directory base = await getTemporaryDirectory();
    return Directory('${base.path}${Platform.pathSeparator}$_dirName').create(recursive: true);
  }

  /// Writes [bytes] to a fresh file named [name] in the private share dir.
  static Future<File> write(String name, List<int> bytes) async {
    final Directory dir = await _dir();
    final File file = File('${dir.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Best-effort delete once the share sheet has returned. share_plus has
  /// already copied the file into its own cache by then.
  static Future<void> delete(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Purged on next start.
    }
  }

  /// Removes every leftover export / backup / picked file. Called at start-up
  /// and after a restore; never throws.
  static Future<void> purge() async {
    try {
      final Directory base = await getTemporaryDirectory();
      for (final String name in <String>[_dirName, ..._pluginCaches]) {
        final Directory d = Directory('${base.path}${Platform.pathSeparator}$name');
        if (await d.exists()) await d.delete(recursive: true);
      }
    } on Exception {
      // Missing path_provider (tests) or a locked file: try again next time.
    }
    try {
      await FilePicker.clearTemporaryFiles();
    } on Exception {
      // Not supported on every platform.
    }
  }
}
