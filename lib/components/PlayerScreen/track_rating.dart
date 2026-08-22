import 'dart:async';

import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/user_rating_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TrackRating extends ConsumerStatefulWidget {
  const TrackRating({super.key, required this.baseItem});

  final BaseItemDto baseItem;

  @override
  ConsumerState<TrackRating> createState() => _TrackRatingState();
}

class _TrackRatingState extends ConsumerState<TrackRating> {
  static const _starWidth = 44.0;
  static const _starCount = 5;

  double? _dragRating;

  double _ratingForPosition(double dx, {required bool allowHalfStars}) {
    if (dx <= 0) return 0;

    final raw = (dx / _starWidth).clamp(0.0, _starCount.toDouble());
    final steps = allowHalfStars ? 2.0 : 1.0;

    return ((raw * steps).ceil() / steps).clamp(allowHalfStars ? 0.5 : 1.0, _starCount.toDouble());
  }

  void _updateDrag(Offset localPosition, {required bool allowHalfStars}) {
    setState(() {
      _dragRating = _ratingForPosition(localPosition.dx, allowHalfStars: allowHalfStars);
    });
  }

  void _finishDrag() {
    final rating = _dragRating;
    if (rating == null) return;

    setState(() => _dragRating = null);
    unawaited(setUserRating(ref, widget.baseItem, rating == 0 ? null : rating));
  }

  void _cancelDrag() {
    if (_dragRating == null) return;
    setState(() => _dragRating = null);
  }

  @override
  Widget build(BuildContext context) {
    final ratingProvider = userRatingProvider(widget.baseItem);
    final rating = ref.watch(ratingProvider);
    final isUpdating = ref.watch(userRatingUpdatingProvider(widget.baseItem.id));
    final allowHalfStars = ref.watch(finampSettingsProvider.allowHalfStarRatings);

    final storedStars = ratingToStarValue(rating);
    final selectedStars = _dragRating ?? (allowHalfStars ? storedStars : storedStars.roundToDouble());

    final displayRating = selectedStars % 1 == 0 ? selectedStars.toInt().toString() : selectedStars.toString();

    final l10n = AppLocalizations.of(context)!;
    final ratingLabel = selectedStars == 0 ? l10n.starRatingNotRated : l10n.starRatingValueLabel(displayRating);

    return Semantics(
      container: true,
      label: ratingLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: isUpdating
            ? null
            : (details) => _updateDrag(details.localPosition, allowHalfStars: allowHalfStars),
        onHorizontalDragUpdate: isUpdating
            ? null
            : (details) => _updateDrag(details.localPosition, allowHalfStars: allowHalfStars),
        onHorizontalDragEnd: isUpdating ? null : (_) => _finishDrag(),
        onHorizontalDragCancel: isUpdating ? null : _cancelDrag,
        child: SizedBox(
          width: _starWidth * _starCount,
          height: _starWidth,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(_starCount, (index) {
              final stars = index + 1;
              final remaining = selectedStars - index;

              final icon = remaining >= 1
                  ? Icons.star_rounded
                  : remaining >= 0.5
                  ? Icons.star_half_rounded
                  : Icons.star_border_rounded;

              final clearsRating = selectedStars == stars;
              final starLabel = l10n.starRatingValueLabel(stars.toString());

              return Semantics(
                button: true,
                enabled: !isUpdating,
                label: starLabel,
                selected: clearsRating,
                excludeSemantics: true,
                child: SizedBox(
                  width: _starWidth,
                  height: _starWidth,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: clearsRating ? l10n.clearStarRating : starLabel,
                    iconSize: 24,
                    onPressed: isUpdating
                        ? null
                        : () => unawaited(setUserRating(ref, widget.baseItem, clearsRating ? null : stars)),
                    icon: Icon(icon),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
