import 'dart:io';

import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';

class ArtistTypeSelectionRow extends StatelessWidget {
  final ContentType tabType;
  final ArtistType defaultArtistType;
  final void Function(ContentType) refreshTab;

  const ArtistTypeSelectionRow({
    super.key,
    required this.tabType,
    required this.defaultArtistType,
    required this.refreshTab,
  });

  @override
  Widget build(BuildContext context) {
    if (tabType == ContentType.genericArtists) {
      double screenWidth = MediaQuery.widthOf(context);
      bool alignLeft = screenWidth > 600;

      return SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
              ? const EdgeInsets.symmetric(horizontal: 4)
              : EdgeInsets.zero,
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: alignLeft ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                FilterChip(
                  label: Text(AppLocalizations.of(context)!.albumArtists),
                  onSelected: (_) {
                    FinampSetters.setDefaultArtistType(ArtistType.albumArtist);
                    refreshTab(tabType);
                  },
                  selected: defaultArtistType == ArtistType.albumArtist,
                  showCheckmark: false,
                  selectedColor: Theme.of(context).colorScheme.primary,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  labelStyle: TextStyle(
                    color: defaultArtistType == ArtistType.albumArtist
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  shape: StadiumBorder(),
                ),
                SizedBox(width: 8),
                FilterChip(
                  label: Text(AppLocalizations.of(context)!.performingArtists),
                  onSelected: (_) {
                    FinampSetters.setDefaultArtistType(ArtistType.artist);
                    refreshTab(tabType);
                  },
                  selected: defaultArtistType == ArtistType.artist,
                  showCheckmark: false,
                  selectedColor: Theme.of(context).colorScheme.primary,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  labelStyle: TextStyle(
                    color: defaultArtistType == ArtistType.artist
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  shape: StadiumBorder(),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SizedBox.shrink();
  }
}
