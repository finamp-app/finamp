import 'package:finamp/components/finamp_app_bar_back_button.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../extensions/localizations.dart';

class ArtistSettingsScreen extends ConsumerStatefulWidget {
  const ArtistSettingsScreen({super.key});
  static const routeName = "/settings/artist";
  @override
  ConsumerState<ArtistSettingsScreen> createState() => _ArtistSettingsScreenState();
}

class _ArtistSettingsScreenState extends ConsumerState<ArtistSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final showArtistsTracksSection = ref.watch(finampSettingsProvider.showArtistsTracksSection);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.artistScreen),
        leading: FinampAppBarBackButton(),
        actions: [
          FinampSettingsHelper.makeSettingsResetButtonWithDialog(context, FinampSettingsHelper.resetArtistSettings),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 200.0),
        children: [
          SwitchListTile.adaptive(
            title: Text(AppLocalizations.of(context)!.showArtistsTracksSection),
            subtitle: Text(AppLocalizations.of(context)!.showArtistsTracksSectionSubtitle),
            value: showArtistsTracksSection,
            onChanged: (value) => FinampSetters.setShowArtistsTracksSection(value),
          ),
          SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: Text(AppLocalizations.of(context)!.itemSectionsOrder),
                subtitle: Text(AppLocalizations.of(context)!.itemSectionsOrderSubtitle),
              ),
              ReorderableListView.builder(
                buildDefaultDragHandles: false,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: FinampSettingsHelper.finampSettings.artistItemSectionsOrder.length,
                itemBuilder: (context, index) {
                  final section = FinampSettingsHelper.finampSettings.artistItemSectionsOrder[index];
                  final isTracksSection = section == ArtistItemSections.tracks;
                  final showTracks = ref.watch(finampSettingsProvider.showArtistsTracksSection);
                  return Opacity(
                    opacity: (isTracksSection && !showTracks) ? 0.4 : 1.0,
                    key: ValueKey(FinampSettingsHelper.finampSettings.artistItemSectionsOrder[index]),
                    child: ReorderableDelayedDragStartListener(
                      index: index,
                      child: ListTile(
                        title: Text(section.toLocalisedString(context.l10n)),
                        leading: ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle)),
                      ),
                    ),
                  );
                },
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (oldIndex < newIndex) newIndex -= 1;
                    final currentOrder = List.of(FinampSettingsHelper.finampSettings.artistItemSectionsOrder);
                    final movedItem = currentOrder.removeAt(oldIndex);
                    currentOrder.insert(newIndex, movedItem);
                    FinampSetters.setArtistItemSectionsOrder(currentOrder);
                  });
                },
              ),
              Divider(),
            ],
          ),
          SizedBox(height: 8),
          Opacity(
            opacity: showArtistsTracksSection ? 1.0 : 0.4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  title: Text(AppLocalizations.of(context)!.artistItemSectionFilterChipOrderTitle),
                  subtitle: Text(AppLocalizations.of(context)!.artistItemSectionFilterChipOrderSubtitle),
                ),
                ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: FinampSettingsHelper.finampSettings.artistItemSectionFilterChipOrder.length,
                  itemBuilder: (context, index) {
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey(FinampSettingsHelper.finampSettings.artistItemSectionFilterChipOrder[index]),
                      index: index,
                      child: ListTile(
                        title: Text(
                          FinampSettingsHelper.finampSettings.artistItemSectionFilterChipOrder[index].toLocalisedString(
                            context.l10n,
                          ),
                        ),
                        leading: ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle)),
                      ),
                    );
                  },
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (oldIndex < newIndex) newIndex -= 1;
                      final currentOrder = List.of(
                        FinampSettingsHelper.finampSettings.artistItemSectionFilterChipOrder,
                      );
                      final movedItem = currentOrder.removeAt(oldIndex);
                      currentOrder.insert(newIndex, movedItem);
                      FinampSetters.setArtistItemSectionFilterChipOrder(currentOrder);
                    });
                  },
                ),
                Divider(),
              ],
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}
