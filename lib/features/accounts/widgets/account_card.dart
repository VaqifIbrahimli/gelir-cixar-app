import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/motion.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import '../../../data/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/settings_controller.dart';

/// The stored photo file of a card, or null when it is missing.
final cardImageFileProvider = FutureProvider.autoDispose.family<File?, String>((Ref ref, String name) async {
  final File? f = await ref.watch(cardImageStoreProvider).fileOf(name);
  return f != null && f.existsSync() ? f : null;
});

/// An account drawn as a 1.586 bank card (DESIGN.md §18.1.4): type icon,
/// name, bonus badge on top; balance, currency and "•••• 1234" at the
/// bottom. Text stays in the top 64dp / bottom 88dp bands, so the photo
/// scrim guarantees contrast.
class AccountCardView extends ConsumerWidget {
  const AccountCardView({
    super.key,
    required this.account,
    required this.balance,
    this.masked = false,
    this.onTap,
    this.onLongPress,
    this.positionLabel,
    this.countUpId,
    this.previewImage,
  });

  final Account account;

  /// Minor units in the account currency; null while loading.
  final int? balance;
  final bool masked;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// "Kart 2 / 17" for the carousel semantics.
  final String? positionLabel;

  /// Count-up id (carousel); null shows the final value at once.
  final String? countUpId;

  /// Editor preview of a photo not yet saved.
  final ImageProvider? previewImage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final String lang = ref.watch(languageProvider);
    final ThemeData theme = Theme.of(context);
    final Brightness b = theme.brightness;
    final AppColors c = AppColors.of(context);
    final AppCardDesign design = AppCardDesigns.byId(account.cardDesignId);
    final String? imageName = account.cardImagePath;

    ImageProvider? image = previewImage;
    bool missing = false;
    if (image == null && design.isPhoto) {
      if (imageName == null) {
        missing = true;
      } else {
        final AsyncValue<File?> f = ref.watch(cardImageFileProvider(imageName));
        final File? file = f.value;
        if (file != null) {
          image = FileImage(file);
        } else if (!f.isLoading) {
          missing = true;
        }
      }
    }
    final bool photo = design.isPhoto && image != null;
    final AppCardDesign shown = design.isPhoto && !photo ? AppCardDesigns.graphite : design;
    final Color onCard = shown.onCard;
    final Color onVariant = photo ? AppCardDesigns.photo.onCardVariant : shown.onCardVariant;
    final List<Shadow>? textShadow = photo ? AppCardDesigns.photoTextShadow : null;
    final double textScale = MediaQuery.textScalerOf(context).scale(1);

    final AccountTypeStyle typeStyle = AccountTypeStyle.forType(account.type);
    final bool negative = (balance ?? 0) < 0;
    final String number = masked
        ? Fmt.mask
        : balance == null
            ? '…'
            : '${negative ? Fmt.minus : ''}${Fmt.number(balance!, lang)}';
    final String last4 = account.cardLast4 == null ? '' : '•••• ${account.cardLast4}';
    final String semantic = <String>[
      accountTypeLabel(l, account.type),
      account.name,
      masked ? Fmt.mask : (balance == null ? '' : Fmt.money(balance!, account.currency, lang)),
      if (account.cardLast4 != null) l.cardEndingIn(account.cardLast4!.split('').join(' ')),
      if (account.type == AccountType.bonus) l.bonusBadge(account.bonusRatePercent),
      ?positionLabel,
    ].where((String s) => s.isNotEmpty).join(', ');

    TextStyle? style(TextStyle? s, Color color) => s?.copyWith(color: color, shadows: textShadow);

    final Widget content = Padding(
      padding: AppCardDesigns.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: AppCardDesigns.typeIcon,
                height: AppCardDesigns.typeIcon,
                decoration: BoxDecoration(color: shown.overlay, shape: BoxShape.circle),
                child: Icon(typeStyle.icon, size: 18, color: onCard),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  account.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style(theme.textTheme.titleMedium, onCard),
                ),
              ),
              if (account.type == AccountType.bonus)
                Container(
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: shown.badge, borderRadius: AppRadius.brFull),
                  child: Text(
                    l.bonusBadge(account.bonusRatePercent),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: shown.onBadge,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (missing && design.isPhoto)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xs),
                  child: Icon(Icons.broken_image_outlined, size: 18, color: onVariant, semanticLabel: l.cardPhotoMissing),
                ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: countUpId == null || masked || balance == null
                ? Text(number, maxLines: 1, style: AppCardDesigns.balanceStyle.copyWith(color: onCard, shadows: textShadow))
                : CountUpAmount(
                    id: countUpId!,
                    value: balance!.abs(),
                    format: (int v) => '${negative ? Fmt.minus : ''}${Fmt.number(v, lang)}',
                    style: AppCardDesigns.balanceStyle.copyWith(color: onCard, shadows: textShadow),
                  ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: <Widget>[
              Text(account.currency, style: style(theme.textTheme.labelMedium, onVariant)),
              if (negative && !masked) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.dangerContainer, borderRadius: AppRadius.brFull),
                  child: Text(
                    l.negativeShort,
                    style: theme.textTheme.labelSmall?.copyWith(color: c.onDangerContainer),
                  ),
                ),
              ],
              const Spacer(),
              if (last4.isNotEmpty)
                Text(last4, style: AppCardDesigns.last4Style.copyWith(color: onVariant, shadows: textShadow)),
            ],
          ),
        ],
      ),
    );

    return LayoutBuilder(builder: (BuildContext context, BoxConstraints box) {
      final double h = box.hasBoundedHeight ? box.maxHeight : box.maxWidth / AppCardDesigns.aspectRatio;
      final double dpr = MediaQuery.devicePixelRatioOf(context);
      final Widget body = photo
          ? DecoratedBox(
              decoration: AppCardDesigns.photoDecoration(
                ResizeImage(image!, width: (box.maxWidth * dpr).round(), allowUpscaling: false),
                b,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: AppCardDesigns.borderRadius,
                  gradient: AppCardDesigns.photoScrimFor(h, textScale: textScale),
                ),
                child: content,
              ),
            )
          : DecoratedBox(decoration: AppCardDesigns.decoration(shown, b), child: content);
      return Semantics(
        button: onTap != null,
        label: semantic,
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: AppCardDesigns.borderRadius,
            onTap: onTap,
            onLongPress: onLongPress,
            child: body,
          ),
        ),
      );
    });
  }
}
