import 'package:finamp/components/SettingsScreen/finamp_settings_dropdown.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../extensions/localizations.dart';
import '../../models/finamp_models.dart';
import '../../services/finamp_settings_helper.dart';
import '../components/finamp_app_bar_back_button.dart';

class ContentViewTypeSettingsScreen extends ConsumerWidget {
  const ContentViewTypeSettingsScreen({super.key});

  static const routeName = "/settings/content-view-type";

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabOrder = ref
        .watch(finampSettingsProvider.tabOrder)
        .where((x) => customContentViewTypes.contains(x))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.tabs),
        leading: FinampAppBarBackButton(),
        actions: [
          FinampSettingsHelper.makeSettingsResetButtonWithDialog(context, () {
            for (var type in customContentViewTypes) {
              FinampSetters.setPerTabContentViewType(type, ContentViewType.list);
            }
          }),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(bottom: 200.0),
        itemCount: tabOrder.length,
        itemBuilder: (context, index) {
          return ContentViewTypeListTile(contentType: tabOrder[index]);
        },
      ),
    );
  }
}

class ContentViewTypeListTile extends ConsumerWidget {
  const ContentViewTypeListTile({super.key, required this.contentType});

  final ContentType contentType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: 15,
        children: [
          Text(contentType.toLocalisedString(context.l10n)),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 200),
              child: FinampSettingsDropdown<ContentViewType>(
                dropdownItems: ContentViewType.values
                    .map(
                      (e) => DropdownMenuEntry<ContentViewType>(
                        value: e,
                        label: e.toLocalisedString(context.l10n),
                        leadingIcon: switch (e) {
                          ContentViewType.list => const Icon(TablerIcons.layout_list),
                          ContentViewType.grid => const Icon(TablerIcons.layout_grid),
                        },
                      ),
                    )
                    .toList(),
                selectedValue: ref.watch(finampSettingsProvider.perTabContentViewType(contentType)),
                onSelected: (value) {
                  switch (value) {
                    case null:
                      break;
                    case ContentViewType.list:
                      FinampSetters.setPerTabContentViewType(contentType, ContentViewType.list);
                    case ContentViewType.grid:
                      FinampSetters.setPerTabContentViewType(contentType, ContentViewType.grid);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// This provides a settings tile which allows you to set all tabs to list/grid mode, or open the per-tab screen
class ContentViewTypeDropdownListTile extends ConsumerStatefulWidget {
  const ContentViewTypeDropdownListTile({super.key});

  @override
  ConsumerState<ContentViewTypeDropdownListTile> createState() => _ContentViewTypeDropdownListTileState();
}

class _ContentViewTypeDropdownListTileState extends ConsumerState<ContentViewTypeDropdownListTile> {
  int resetDropdown = 0;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.viewType),
      subtitle: Column(
        spacing: 4.0,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.viewTypeSubtitle),
          FinampSettingsDropdown<DropdownContentViewType>(
            key: ValueKey(resetDropdown),
            dropdownItems: DropdownContentViewType.values
                .map(
                  (e) => DropdownMenuEntry<DropdownContentViewType>(
                    value: e,
                    label: e.toLocalizedString(context.l10n),
                    leadingIcon: switch (e) {
                      DropdownContentViewType.list => const Icon(TablerIcons.layout_list),
                      DropdownContentViewType.grid => const Icon(TablerIcons.layout_grid),
                      DropdownContentViewType.custom => Icon(null),
                      DropdownContentViewType.albumGrid => Icon(null),
                    },
                  ),
                )
                .toList(),
            selectedValue: watchDropdownContentViewType(ref),
            onSelected: (value) {
              switch (value) {
                case null:
                  break;
                case DropdownContentViewType.custom:
                  Navigator.of(context).pushNamed(ContentViewTypeSettingsScreen.routeName);
                  setState(() {
                    resetDropdown++;
                  });
                case DropdownContentViewType.list:
                  for (var type in customContentViewTypes) {
                    FinampSetters.setPerTabContentViewType(type, ContentViewType.list);
                  }
                case DropdownContentViewType.grid:
                  for (var type in customContentViewTypes) {
                    FinampSetters.setPerTabContentViewType(type, ContentViewType.grid);
                  }
                case DropdownContentViewType.albumGrid:
                  for (var type in customContentViewTypes) {
                    if (type == ContentType.albums) {
                      FinampSetters.setPerTabContentViewType(type, ContentViewType.grid);
                    } else {
                      FinampSetters.setPerTabContentViewType(type, ContentViewType.list);
                    }
                  }
              }
            },
          ),
        ],
      ),
    );
  }
}

enum DropdownContentViewType {
  list,
  grid,
  albumGrid,
  custom;

  String toLocalizedString(AppLocalizations l10n) => switch (this) {
    DropdownContentViewType.list => l10n.list,
    DropdownContentViewType.grid => l10n.grid,
    DropdownContentViewType.custom => l10n.perTabGridMode,
    DropdownContentViewType.albumGrid => l10n.perTabAlbumGrid,
  };
}

Iterable<ContentType> get customContentViewTypes =>
    ContentType.values.where((x) => x.isTab && x != ContentType.home && x != ContentType.tracks);

DropdownContentViewType watchDropdownContentViewType(WidgetRef ref) {
  ContentViewType? prev;
  ContentViewType? albums;
  for (var type in customContentViewTypes) {
    final view = ref.watch(finampSettingsProvider.perTabContentViewType(type));
    if (type == ContentType.albums) {
      albums = view;
    } else {
      if (prev == null) {
        prev = view;
      } else if (prev != view) {
        return DropdownContentViewType.custom;
      }
    }
  }
  // We do not actually expect either variable to be null at this point.
  return switch (prev) {
    null => DropdownContentViewType.custom,
    ContentViewType.list => switch (albums) {
      null => DropdownContentViewType.list,
      ContentViewType.list => DropdownContentViewType.list,
      ContentViewType.grid => DropdownContentViewType.albumGrid,
    },
    ContentViewType.grid => DropdownContentViewType.grid,
  };
}
