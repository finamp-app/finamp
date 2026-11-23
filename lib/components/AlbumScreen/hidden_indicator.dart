import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/hidden_items_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

/// Crossed-out eye shown next to the download indicator, so a hidden track doesn't look like an undownloaded one
/// (both are dimmed in offline mode).
class HiddenIndicator extends ConsumerWidget {
  const HiddenIndicator({super.key, required this.item, this.size});

  final BaseItemDto item;
  final double? size;

  bool isVisible(WidgetRef ref) => ref.watch(isHiddenProvider(item));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isVisible(ref)) return const SizedBox.shrink();
    return Icon(TablerIcons.eye_off, size: size, semanticLabel: AppLocalizations.of(context)!.hiddenIndicatorLabel);
  }
}
