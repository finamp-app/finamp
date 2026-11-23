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

/// Darkens hidden cover art and puts a crossed-out eye over it, like the visualizer over the playing track's cover.
class HiddenArtOverlay extends ConsumerWidget {
  const HiddenArtOverlay({super.key, required this.item, required this.child, this.borderRadius});

  final BaseItemDto item;
  final Widget child;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isHiddenProvider(item))) return child;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          foregroundDecoration: BoxDecoration(borderRadius: borderRadius, color: Colors.black.withValues(alpha: 0.4)),
          child: child,
        ),
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) => Icon(
              TablerIcons.eye_off,
              color: Colors.white,
              size: (constraints.biggest.shortestSide * 0.35).clamp(16.0, 48.0),
              semanticLabel: AppLocalizations.of(context)!.hiddenIndicatorLabel,
            ),
          ),
        ),
      ],
    );
  }
}
