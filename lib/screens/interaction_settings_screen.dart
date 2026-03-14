import 'package:finamp/components/InteractionSettingsScreen/FastScrollSelector.dart';
import 'package:finamp/components/InteractionSettingsScreen/auto_expand_player_screen.dart';
import 'package:finamp/components/InteractionSettingsScreen/item_swipe_action_dropdown_list_tile.dart';
import 'package:finamp/components/InteractionSettingsScreen/keep_screen_on_dropdown_list_tile.dart';
import 'package:finamp/components/InteractionSettingsScreen/keep_screen_on_while_charging_selector.dart';
import 'package:finamp/components/InteractionSettingsScreen/previous_tracks_persistence_mode_dropdown_list_tile.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/screens/layout_settings_screen.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InteractionSettingsScreen extends StatefulWidget {
  const InteractionSettingsScreen({super.key});
  static const routeName = "/settings/interactions";
  @override
  State<InteractionSettingsScreen> createState() => _InteractionSettingsScreenState();
}

class _InteractionSettingsScreenState extends State<InteractionSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.interactions),
        actions: [
          FinampSettingsHelper.makeSettingsResetButtonWithDialog(
            context,
            FinampSettingsHelper.resetInteractionsSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 200.0),
        children: const [
          ItemSwipeLeftToRightActionDropdownListTile(),
          ItemSwipeRightToLeftActionDropdownListTile(),
          StartInstantMixForIndividualTracksSwitch(),
          ApplyFilterOnGenreChipTapSwitch(),
          AutoSwitchItemCurationTypeToggle(),
          FastScrollSelector(),
          AutoExpandPlayerScreenSelector(),
          ShowDeleteFromServerOptionToggle(),
          KeepScreenOnDropdownListTile(),
          KeepScreenOnWhilePluggedInSelector(),
          PreferAddingToFavoritesOverPlaylistsToggle(),
          PreferNextUpPrependingToggle(),
          RememberLastUsedPlaybackActionRowPageToggle(),
          PreviousTracksPersistenceModeSelector(),
        ],
      ),
    );
  }
}

class StartInstantMixForIndividualTracksSwitch extends ConsumerWidget {
  const StartInstantMixForIndividualTracksSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.startInstantMixForIndividualTracksSwitchTitle),
      subtitle: Text(AppLocalizations.of(context)!.startInstantMixForIndividualTracksSwitchSubtitle),
      value: ref.watch(finampSettingsProvider.startInstantMixForIndividualTracks),
      onChanged: FinampSetters.setStartInstantMixForIndividualTracks,
    );
  }
}

class ApplyFilterOnGenreChipTapSwitch extends ConsumerWidget {
  const ApplyFilterOnGenreChipTapSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.applyFilterOnGenreChipTapTitle),
      subtitle: Text(AppLocalizations.of(context)!.applyFilterOnGenreChipTapSubtitle),
      value: ref.watch(finampSettingsProvider.applyFilterOnGenreChipTap),
      onChanged: FinampSetters.setApplyFilterOnGenreChipTap,
    );
  }
}

class ShowDeleteFromServerOptionToggle extends ConsumerWidget {
  const ShowDeleteFromServerOptionToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.allowDeleteFromServerTitle),
      subtitle: Text(AppLocalizations.of(context)!.allowDeleteFromServerSubtitle),
      value: ref.watch(finampSettingsProvider.allowDeleteFromServer),
      onChanged: FinampSetters.setAllowDeleteFromServer,
    );
  }
}

class PreferAddingToFavoritesOverPlaylistsToggle extends ConsumerWidget {
  const PreferAddingToFavoritesOverPlaylistsToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.preferAddingToFavoritesOverPlaylistsTitle),
      subtitle: Text(AppLocalizations.of(context)!.preferAddingToFavoritesOverPlaylistsSubtitle),
      value: ref.watch(finampSettingsProvider.preferAddingToFavoritesOverPlaylists),
      onChanged: (value) => FinampSetters.setPreferAddingToFavoritesOverPlaylists(value),
    );
  }
}

class PreferNextUpPrependingToggle extends ConsumerWidget {
  const PreferNextUpPrependingToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.preferNextUpPrependingTitle),
      subtitle: Text(AppLocalizations.of(context)!.preferNextUpPrependingSubtitle),
      value: ref.watch(finampSettingsProvider.preferNextUpPrepending),
      onChanged: (value) => FinampSetters.setPreferNextUpPrepending(value),
    );
  }
}

class RememberLastUsedPlaybackActionRowPageToggle extends ConsumerWidget {
  const RememberLastUsedPlaybackActionRowPageToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.rememberLastUsedPlaybackActionRowPageTitle),
      subtitle: Text(AppLocalizations.of(context)!.rememberLastUsedPlaybackActionRowPageSubtitle),
      value: ref.watch(finampSettingsProvider.rememberLastUsedPlaybackActionRowPage),
      onChanged: (value) => FinampSetters.setRememberLastUsedPlaybackActionRowPage(value),
    );
  }
}
