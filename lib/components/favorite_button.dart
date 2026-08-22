import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/favorite_provider.dart';

class FavoriteButton extends ConsumerStatefulWidget {
  const FavoriteButton({
    super.key,
    required this.item,
    this.onlyIfFav = false,
    this.inPlayer = false,
    this.color,
    this.size,
    this.visualDensity,
    this.showFavoriteIconOnlyWhenFilterDisabled = false,
  });

  final BaseItemDto? item;
  final bool onlyIfFav;
  final bool inPlayer;
  final Color? color;
  final double? size;
  final VisualDensity? visualDensity;
  final bool showFavoriteIconOnlyWhenFilterDisabled;

  @override
  ConsumerState<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<FavoriteButton> {
  @override
  Widget build(BuildContext context) {
    final isOffline = ref.watch(finampSettingsProvider.isOffline);

    if (widget.item == null) {
      return const SizedBox.shrink();
    }

    bool isFav = ref.watch(isFavoriteProvider(widget.item));
    if (widget.onlyIfFav) {
      if (isFav &&
          (!widget.showFavoriteIconOnlyWhenFilterDisabled || !ref.watch(finampSettingsProvider.onlyShowFavorites))) {
        return Icon(
          Icons.favorite,
          color: Colors.red,
          size: widget.size ?? 24.0,
          semanticLabel: AppLocalizations.of(context)!.favorite,
        );
      } else {
        return const SizedBox.shrink();
      }
    } else {
      return IconButton(
        icon: Icon(isFav ? Icons.favorite : Icons.favorite_outline, size: widget.size ?? 24.0),
        color: widget.color ?? IconTheme.of(context).color,
        disabledColor: (widget.color ?? IconTheme.of(context).color)!.withValues(alpha: 0.3),
        visualDensity: widget.visualDensity ?? VisualDensity.compact,
        tooltip: AppLocalizations.of(context)!.favorite,
        onPressed: isOffline
            ? null
            : () {
                ref.read(isFavoriteProvider(widget.item).notifier).updateFavorite(!isFav);
              },
      );
    }
  }
}
