import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_info.dart';
import '../../core/share_files.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';

/// Writes a JSON backup to the private cache, opens the share sheet and
/// deletes the file again.
Future<void> createBackup(BuildContext context, WidgetRef ref) async {
  final AppLocalizations l = AppLocalizations.of(context);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  File? file;
  try {
    final String version = await _version(ref);
    final String json = await ref.read(backupServiceProvider).exportJson(appVersion: version);
    final DateTime now = DateTime.now();
    final String stamp = '${monthKey(now).replaceAll('-', '')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    file = await ShareFiles.write('gelir_cixar_backup_$stamp.json', utf8.encode(json));
    await SharePlus.instance.share(ShareParams(
      files: <XFile>[XFile(file.path, mimeType: 'application/json')],
      subject: l.backupShareSubject,
      title: l.backupCreate,
    ));
  } on Exception {
    messenger.showSnackBar(SnackBar(content: Text(l.backupFailed)));
  } finally {
    if (file != null) await ShareFiles.delete(file);
  }
}

Future<String> _version(WidgetRef ref) async {
  try {
    return (await ref.read(packageInfoProvider.future)).version;
  } on Exception {
    return '?';
  }
}

/// Picks a backup file, confirms, and replaces all data.
Future<void> restoreBackup(BuildContext context, WidgetRef ref) async {
  final AppLocalizations l = AppLocalizations.of(context);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

  final PlatformFile? picked = await FilePicker.pickFile(dialogTitle: l.backupRestore);
  if (picked == null || !context.mounted) return;

  final String content;
  try {
    // Refuse oversized files before reading them into memory.
    final int? size = await picked.length();
    if (size == null || size > BackupService.maxBytes) {
      await ShareFiles.purge();
      messenger.showSnackBar(SnackBar(content: Text(l.backupTooLarge)));
      return;
    }
    final List<int> bytes = await picked.readAsBytes();
    if (bytes.length > BackupService.maxBytes) {
      await ShareFiles.purge();
      messenger.showSnackBar(SnackBar(content: Text(l.backupTooLarge)));
      return;
    }
    content = utf8.decode(bytes);
  } on FormatException {
    await ShareFiles.purge();
    messenger.showSnackBar(SnackBar(content: Text(l.backupInvalidFile)));
    return;
  } on Exception {
    await ShareFiles.purge();
    messenger.showSnackBar(SnackBar(content: Text(l.backupReadFailed)));
    return;
  }
  // file_picker keeps a private copy of the picked file; drop it now that
  // the content is in memory.
  await ShareFiles.purge();
  if (!context.mounted) return;

  final bool ok = await confirmDialog(
    context,
    title: l.backupRestoreConfirmTitle,
    message: l.backupRestoreConfirmBody(picked.name),
    confirmLabel: l.backupRestoreConfirmAction,
    destructive: true,
  );
  if (!ok) return;

  try {
    final BackupSummary s = await ref.read(backupServiceProvider).restoreJson(content);
    messenger.showSnackBar(SnackBar(
      content: Text(l.backupRestored(s.transactions, s.accounts)),
    ));
  } on BackupException catch (e) {
    final String msg = switch (e.reason) {
      BackupFailure.notJson || BackupFailure.wrongFormat => l.backupInvalidFile,
      BackupFailure.newerSchema => l.backupNewerVersion,
      BackupFailure.invalidData => l.backupInvalidData,
      BackupFailure.tooLarge => l.backupTooLarge,
    };
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }
}
