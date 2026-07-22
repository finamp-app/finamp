import 'package:finamp/components/AlbumScreen/download_button.dart';
import 'package:finamp/components/toggleable_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../extensions/localizations.dart';
import '../../models/finamp_models.dart';
import '../../models/jellyfin_models.dart';
import '../../services/finamp_user_helper.dart';
import '../view_icon.dart';

class ViewListTile extends ConsumerWidget {
  const ViewListTile({super.key, required this.view});

  final BaseItemDto view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finampUserHelper = GetIt.instance<FinampUserHelper>();

    var currentViewId = ref.watch(FinampUserHelper.finampCurrentUserProvider.select((value) => value?.currentViewId));

    return Semantics.fromProperties(
      properties: SemanticsProperties(label: view.name, selected: currentViewId == view.id),
      container: true,
      child: ToggleableListTile(
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0, right: 6.0),
          child: ViewIcon(
            collectionType: view.collectionType,
            color: currentViewId == view.id ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
        title: view.name ?? context.l10n.unknownName,
        subtitle: currentViewId == view.id ? context.l10n.libraryQualifierActive : null,
        trailing: DownloadButton(
          isLibrary: true,
          item: DownloadStub.fromItem(item: view, type: DownloadItemType.collection),
        ),
        condensed: true,
        state: currentViewId == view.id,
        onToggle: (bool currentState) async {
          finampUserHelper.setCurrentUserCurrentViewId(view.id);
          await Future<void>.delayed(const Duration(milliseconds: 400));
          // update state first to give visual feedback, then close menu
          if (!context.mounted) return;
          Navigator.of(context).pop();
        },
        lowContrast: true,
      ),
      // child: Material(
      //   color: Colors.transparent,
      //   child: ListTile(
      //     leading: Padding(
      //       padding: const EdgeInsets.only(right: 16),
      // child: ViewIcon(
      //   collectionType: view.collectionType,
      //   color: currentViewId == view.id ? Theme.of(context).colorScheme.primary : null,
      // ),
      //     ),
      //     title: Text(
      //       view.name ?? context.l10n.unknownName,
      //       semanticsLabel: "", // covered by SemanticsProperties
      //       style: TextStyle(color: currentViewId == view.id ? Theme.of(context).colorScheme.primary : null),
      //     ),
      //     onTap: () {
      //       finampUserHelper.setCurrentUserCurrentViewId(view.id);
      //       Navigator.of(context).pop();
      //     },
      //     trailing: DownloadButton(
      //       isLibrary: true,
      //       item: DownloadStub.fromItem(item: view, type: DownloadItemType.collection),
      //     ),
      //   ),
      // ),
    );
  }
}
