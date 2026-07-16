import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'song_selection_controller.dart';

/// Close (X) button that leaves selection mode.
Widget selectionCloseButton(
    BuildContext context, SongSelectionController controller) {
  return IconButton(
    icon: const Icon(Icons.close),
    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
    onPressed: controller.endSelection,
  );
}

/// "N selected" title for the selection app bar.
Widget selectionTitle(
    BuildContext context, SongSelectionController controller) {
  return Text(
    AppLocalizations.of(context)!.itemsSelected(controller.selectedCount),
  );
}

/// Select-all / deselect-all toggle for the selection app bar. Only shown when
/// the surface exposes a list of selectable items.
List<Widget> selectionAppBarActions(
    BuildContext context, SongSelectionController controller) {
  if (!controller.hasSelectableItems) return const [];
  final allSelected = controller.allSelectableSelected;
  return [
    IconButton(
      icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
      tooltip: allSelected
          ? AppLocalizations.of(context)!.deselectAll
          : AppLocalizations.of(context)!.selectAll,
      onPressed: allSelected ? controller.deselectAll : controller.selectAll,
    ),
  ];
}

/// A regular [AppBar] shown while in selection mode (used by screens whose app
/// bar is a plain [AppBar], e.g. the Music screen). Screens whose app bar is a
/// [SliverAppBar] build one inline using the helpers above.
class SelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SelectionAppBar({
    Key? key,
    required this.controller,
    this.bottom,
  }) : super(key: key);

  final SongSelectionController controller;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: selectionCloseButton(context, controller),
      title: selectionTitle(context, controller),
      actions: selectionAppBarActions(context, controller),
      bottom: bottom,
    );
  }
}
