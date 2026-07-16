import 'package:flutter/foundation.dart';

import '../models/jellyfin_models.dart';

/// Ephemeral, screen-scoped controller that tracks the multi-select state of a
/// list of songs.
///
/// It is provided to a screen subtree via a `ChangeNotifierProvider`.
/// [SongListTile] looks it up with a *nullable* `context.watch` so that screens
/// which don't provide one keep their original (non-selecting) behaviour, and
/// no existing call site needs to change.
class SongSelectionController extends ChangeNotifier {
  bool _isSelecting = false;

  // Insertion-ordered so that batch actions (e.g. adding to the queue) preserve
  // the order in which songs were selected. Keyed by [BaseItemDto.id].
  final Map<String, BaseItemDto> _selected = <String, BaseItemDto>{};

  List<BaseItemDto> _selectable = const [];

  /// The parent the current surface belongs to, when it is a single album or
  /// playlist. Used as the download parent and to enable the
  /// "remove from playlist" action. Null on surfaces without a single parent
  /// (e.g. the Songs tab).
  BaseItemDto? parent;

  /// Called after items have been removed from the underlying list by a batch
  /// action (currently "remove from playlist") so the surface can drop them
  /// from its in-memory list and rebuild.
  void Function(List<BaseItemDto> removed)? onItemsRemoved;

  bool get isSelecting => _isSelecting;

  int get selectedCount => _selected.length;

  bool get hasSelection => _selected.isNotEmpty;

  /// Selected items, in selection order.
  List<BaseItemDto> get selectedItems => _selected.values.toList();

  bool isSelected(BaseItemDto item) => _selected.containsKey(item.id);

  /// True when the current surface is a playlist, enabling the
  /// "remove from playlist" batch action.
  bool get isPlaylist => parent?.type == "Playlist";

  /// The set of items the current surface can select, used for "select all".
  /// The list widget updates this as its data changes (including as more pages
  /// load on paginated surfaces). Does not notify, since it is called from
  /// build.
  void setSelectableItems(List<BaseItemDto> items) {
    _selectable = items;
  }

  bool get hasSelectableItems => _selectable.isNotEmpty;

  bool get allSelectableSelected =>
      _selectable.isNotEmpty &&
      _selectable.every((e) => _selected.containsKey(e.id));

  /// Enters selection mode with [item] selected.
  void startSelection(BaseItemDto item) {
    _isSelecting = true;
    _selected[item.id] = item;
    notifyListeners();
  }

  /// Toggles whether [item] is selected. Does nothing to the mode itself, so
  /// deselecting the last item keeps the user in selection mode (matching apps
  /// like QQ Music, where you exit explicitly).
  void toggle(BaseItemDto item) {
    if (_selected.containsKey(item.id)) {
      _selected.remove(item.id);
    } else {
      _selected[item.id] = item;
    }
    notifyListeners();
  }

  void selectAll() {
    for (final item in _selectable) {
      _selected[item.id] = item;
    }
    notifyListeners();
  }

  void deselectAll() {
    _selected.clear();
    notifyListeners();
  }

  /// Removes [items] from the current selection (e.g. after they were removed
  /// from a playlist).
  void removeFromSelection(List<BaseItemDto> items) {
    for (final item in items) {
      _selected.remove(item.id);
    }
    notifyListeners();
  }

  /// Exits selection mode and clears the selection.
  void endSelection() {
    _isSelecting = false;
    _selected.clear();
    notifyListeners();
  }
}
