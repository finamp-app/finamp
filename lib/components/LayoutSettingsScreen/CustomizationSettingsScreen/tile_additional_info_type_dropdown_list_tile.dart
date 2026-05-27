import 'package:finamp/components/SettingsScreen/finamp_settings_dropdown.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../extensions/localizations.dart';

class TileAdditionalInfoTypeTitleListTile extends ConsumerWidget {
  const TileAdditionalInfoTypeTitleListTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.additionalBaseItemInfoTitle),
      subtitle: Text(AppLocalizations.of(context)!.additionalBaseItemInfoSubtitle),
    );
  }
}

class TileAdditionalInfoTypeDropdownListTile extends ConsumerWidget {
  final ContentType tabContentType;

  const TileAdditionalInfoTypeDropdownListTile({required this.tabContentType, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tileAdditionalInfoType = ref.watch(finampSettingsProvider.tileAdditionalInfoType(tabContentType));
    final currentType = tileAdditionalInfoType ?? TileAdditionalInfoType.adaptive;

    // Filter dropdown items based on tabContentType
    final dropdownItems = [
      TileAdditionalInfoType.adaptive,
      TileAdditionalInfoType.dateAdded,
      if ([ContentType.tracks, ContentType.albums].contains(tabContentType)) TileAdditionalInfoType.dateReleased,
      if ([ContentType.tracks].contains(tabContentType)) TileAdditionalInfoType.playCount,
      if ([ContentType.tracks].contains(tabContentType)) TileAdditionalInfoType.dateLastPlayed,
      if ([
        ContentType.albums,
        ContentType.albumArtists,
        ContentType.performingArtists,
        ContentType.playlists,
      ].contains(tabContentType))
        TileAdditionalInfoType.duration,
      TileAdditionalInfoType.none,
    ];

    return ListTile(
      title: Text(tabContentType.toLocalisedString(context.l10n)),
      subtitle: FinampSettingsDropdown<TileAdditionalInfoType>(
        dropdownItems: dropdownItems
            .map((e) => DropdownMenuEntry<TileAdditionalInfoType>(value: e, label: e.toLocalisedString(context.l10n)))
            .toList(),
        selectedValue: currentType,
        onSelected: (value) {
          if (value != null) {
            FinampSetters.setTileAdditionalInfoType(tabContentType, value);
          }
        },
      ),
    );
  }
}
