import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/jellyfin_models.dart';

/// Ephemeral, per-surface multi-select state for track lists.
///
/// Keyed by a scope string (e.g. the album/playlist id) via [trackSelectionProvider]
/// so that different track lists don't share a selection. A [TrackListTile] only
/// participates when it is given a `selectionScope`, so every other use of the
/// tile (e.g. playback history) keeps its original behaviour.
@immutable
class TrackSelectionState {
  const TrackSelectionState({this.isSelecting = false, this.selected = const {}});

  final bool isSelecting;

  /// Selected tracks, insertion-ordered so batch actions preserve selection order.
  final Map<BaseItemId, BaseItemDto> selected;

  int get count => selected.length;

  bool get hasSelection => selected.isNotEmpty;

  List<BaseItemDto> get selectedItems => selected.values.toList();

  bool isSelected(BaseItemDto item) => selected.containsKey(item.id);

  /// Whether every item in [candidates] is currently selected (used to drive the
  /// select-all / deselect-all toggle against the surface's full list).
  bool allSelected(List<BaseItemDto> candidates) =>
      candidates.isNotEmpty && candidates.every((e) => selected.containsKey(e.id));

  TrackSelectionState copyWith({bool? isSelecting, Map<BaseItemId, BaseItemDto>? selected}) =>
      TrackSelectionState(isSelecting: isSelecting ?? this.isSelecting, selected: selected ?? this.selected);
}

class TrackSelectionNotifier extends FamilyNotifier<TrackSelectionState, String> {
  @override
  TrackSelectionState build(String arg) => const TrackSelectionState();

  /// Enters selection mode with [item] selected.
  void startSelection(BaseItemDto item) {
    state = state.copyWith(isSelecting: true, selected: {...state.selected, item.id: item});
  }

  void toggle(BaseItemDto item) {
    final next = Map<BaseItemId, BaseItemDto>.of(state.selected);
    if (next.containsKey(item.id)) {
      next.remove(item.id);
    } else {
      next[item.id] = item;
    }
    state = state.copyWith(selected: next);
  }

  /// Adds all of [items] to the selection (used for "select all").
  void selectAll(List<BaseItemDto> items) {
    final next = Map<BaseItemId, BaseItemDto>.of(state.selected);
    for (final item in items) {
      next[item.id] = item;
    }
    state = state.copyWith(selected: next);
  }

  void deselectAll() => state = state.copyWith(selected: const {});

  void removeFromSelection(Iterable<BaseItemDto> items) {
    final next = Map<BaseItemId, BaseItemDto>.of(state.selected);
    for (final item in items) {
      next.remove(item.id);
    }
    state = state.copyWith(selected: next);
  }

  /// Exits selection mode and clears the selection.
  void endSelection() => state = const TrackSelectionState();
}

final trackSelectionProvider = NotifierProvider.family<TrackSelectionNotifier, TrackSelectionState, String>(
  TrackSelectionNotifier.new,
);
