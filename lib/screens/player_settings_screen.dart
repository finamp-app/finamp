import 'package:collection/collection.dart';
import 'package:finamp/components/finamp_app_bar_back_button.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/screens/customization_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/LayoutSettingsScreen/player_screen_minimum_cover_padding_editor.dart';
import '../extensions/localizations.dart';
import '../models/finamp_models.dart';
import '../services/finamp_settings_helper.dart';

class PlayerSettingsScreen extends ConsumerWidget {
  const PlayerSettingsScreen({super.key});
  static const routeName = "/settings/player";

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.playerScreen),
        leading: FinampAppBarBackButton(),
        actions: [
          FinampSettingsHelper.makeSettingsResetButtonWithDialog(
            context,
            FinampSettingsHelper.resetPlayerScreenSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 200.0),
        children: [
          ShowFeatureChipsToggle(),
          if (ref.watch(finampSettingsProvider.featureChipsConfiguration).enabled)
            ReorderableListView(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(), // Disable scrolling on inner list
              buildDefaultDragHandles: false,
              children:
                  Set.of(
                    ref
                        .read(finampSettingsProvider.featureChipsConfiguration)
                        .features
                        .followedBy(FinampFeatureChipType.values),
                  ).mapIndexed((index, feature) {
                    return FeatureChipToggle(
                      key: ValueKey(feature),
                      feature: feature,
                      index: index,
                      canBeReordered: ref
                          .read(finampSettingsProvider.featureChipsConfiguration)
                          .features
                          .contains(feature),
                    );
                  }).toList(),
              onReorderItem: (oldIndex, newIndex) {
                final oldFeatureChipsConfig = ref.read(finampSettingsProvider.featureChipsConfiguration);
                final oldFeatures = List.of(oldFeatureChipsConfig.features);

                // move all values below newIndex down by one
                final oldFeature = oldFeatures[oldIndex];
                oldFeatures.removeAt(oldIndex);
                oldFeatures.insert(newIndex, oldFeature);
                FinampSetters.setFeatureChipsConfiguration(oldFeatureChipsConfig.copyWith(features: oldFeatures));
              },
            ),
          ShowAlbumReleaseDateOnPlayerScreenToggle(),
          PlayerScreenMinimumCoverPaddingEditor(),
          SuppressPlayerPaddingSwitch(),
          PrioritizeCoverSwitch(),
          HidePlayerBottomActionsSwitch(),
        ],
      ),
    );
  }
}

class SuppressPlayerPaddingSwitch extends ConsumerWidget {
  const SuppressPlayerPaddingSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.suppressPlayerPadding),
      subtitle: Text(AppLocalizations.of(context)!.suppressPlayerPaddingSubtitle),
      value: ref.watch(finampSettingsProvider.suppressPlayerPadding),
      onChanged: FinampSetters.setSuppressPlayerPadding,
    );
  }
}

class HidePlayerBottomActionsSwitch extends ConsumerWidget {
  const HidePlayerBottomActionsSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.hidePlayerBottomActions),
      subtitle: Text(AppLocalizations.of(context)!.hidePlayerBottomActionsSubtitle),
      value: ref.watch(finampSettingsProvider.hidePlayerBottomActions),
      onChanged: FinampSetters.setHidePlayerBottomActions,
    );
  }
}

class PrioritizeCoverSwitch extends ConsumerWidget {
  const PrioritizeCoverSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.prioritizePlayerCover),
      subtitle: Text(AppLocalizations.of(context)!.prioritizePlayerCoverSubtitle),
      value: ref.watch(finampSettingsProvider.prioritizeCoverFactor) < 6,
      onChanged: (value) => FinampSetters.setPrioritizeCoverFactor(value ? 3.0 : 8.0),
    );
  }
}

class ShowFeatureChipsToggle extends ConsumerWidget {
  const ShowFeatureChipsToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.showFeatureChipsToggleTitle),
      subtitle: Text(AppLocalizations.of(context)!.showFeatureChipsToggleSubtitle),
      value: ref.watch(finampSettingsProvider.featureChipsConfiguration).enabled,
      onChanged: (value) {
        FinampSetters.setFeatureChipsConfiguration(
          FinampSettingsHelper.finampSettings.featureChipsConfiguration.copyWith(enabled: value),
        );
      },
    );
  }
}

class FeatureChipToggle extends ConsumerWidget {
  const FeatureChipToggle({super.key, required this.feature, required this.index, required this.canBeReordered});

  final FinampFeatureChipType feature;
  final int index;
  final bool canBeReordered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitle = context.l10n.featureChipDescription(feature.name);
    return Padding(
      padding: const EdgeInsets.only(left: 40.0),
      child: SwitchListTile.adaptive(
        title: Text(context.l10n.featureChipName(feature.name)),
        subtitle: subtitle == "null" ? null : Text(subtitle),
        secondary: canBeReordered
            ? ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle))
            : null,
        value: ref.watch(finampSettingsProvider.featureChipsConfiguration).features.contains(feature),
        onChanged: (value) {
          final config = FinampSettingsHelper.finampSettings.featureChipsConfiguration;
          final feat = List.of(config.features);
          if (value) {
            feat.add(feature);
          } else {
            feat.remove(feature);
          }
          FinampSetters.setFeatureChipsConfiguration(config.copyWith(features: feat));
        },
      ),
    );
  }
}
